ruleset gossip.node {
    meta {
        name "Gossip Node"
        description <<
            A ruleset for a node in the gossip protocol
        >>
        author "Forrest Olson"
        shares heartbeat_period, sensors, subscriptions, myFullState
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
        use module temperature_store alias temps
    }
    global {
        heartbeat_period = function() { ent:heartbeat_period.defaultsTo(default_heartbeat_period) };

        default_heartbeat_period = 15; //seconds

        sensors = function() {
            ent:sensors.defaultsTo("no sensors")
        }

        subscriptions = function() {
            ent:subscriptions.defaultsTo("no subscriptions")
        }

        identify_myself_to_parent = defaction(parent_eci, sensor_id, wellKnown_eci) {
            event:send({
                "eci": parent_eci,
                "domain": "sensor", "type": "identify",
                "attrs": {
                    "sensor_id": sensor_id,
                    "wellKnown_eci": wellKnown_eci
                }
            })
        }

        last_message = function() {
            ent:last_message.defaultsTo(0)
        }

        current_message = function() { // maybe?
            ent:current_message.defaultsTo(1)
        } 
        current_temp = function() {
            temps:current_temp()
        }
        // {} state starts blank, adds one each time
        // 1 of 4
        getPeer = function(state) {
            ent:subscriptions{ent:seen.keys()[0]}{"tx"}.klog("ent_ssen_keys:")
            // filter the connections that have seen < my last Message
        }
        prepareRumor = function() {
            {
                "message_origin_id": ent:sensor_id,
                "message_id": current_message(), // rather ent:current_message++
                "temp_origin_id": 2, // either self or some node from a current state 
                "temperature": current_temp(){"temp"}, // etiher self or some node, current_temp().get("temp")
                "timestamp":  current_temp(){"time"}// either self or some node, current_temp().get("time")
            }
        }
        prepareMessage = function(state, subscriber) {
            prepareRumor()
        }
        // update = defaction(state) {
        // }
        send = defaction(subscriber, m) {
            event:send({
                "eci": subscriber,
                "domain": "gossip", "name": "rumor", // message type...
                "attrs": {
                    "message":m
                }
            })
        }
        seenMessage = function() {
            ent:seen.defaultsTo("nada")
        }
        gossipState = function() { // map of sensors to last message number
            ent:seen.defaultsTo("none")
        }
        myFullState = function() {
            {
                "seen": ent:seen,
                "rumors": ent:rumors
            }
        }
    }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid

        pre {
            sensor_id = event:attrs{"sensor_id"}
            parent_eci = wrangler:parent_eci()
            wellKnown_eci = subs:wellKnown_Rx(){"id"}
        }

        identify_myself_to_parent(parent_eci, sensor_id, wellKnown_eci)

        always {
            ent:seen := {}
            ent:rumors := {}
            // ent:sensor_collection_wellKnown_eci := sensor_collection_wellKnown_eci // is this needed?
            ent:sensor_id := sensor_id
            ent:last_message := 0
            // raise sensor event "new_subscription_request"
            raise gossip event "heartbeat"
            // schedule gossip event "heartbeat" repeat << */#{period} * * * * * >> attributes {}
        }
    }

    rule add_subscription {
        select when wrangler subscription_added 
        
        pre {
            my_role = event:attrs{"Rx_role"}.klog("myrole")
            their_role = event:attrs{"Tx_role"}.klog("theirsrole")
            sensor_id = subs:wellKnown_Rx().klog("anything?"){"id"}.klog("mine RX") == event:attrs{"wellKnown_Tx"}.klog("the WLEKON") =>  // you are in sensor two...
                            event:attrs{"rx_node"}.klog("eys") | event:attrs{"tx_node"}.klog("correc?Itd?")
            subInfo = {
                "id": event:attrs{"bus"}{"Id"},
                "rx": event:attrs{"bus"}{"Rx"},
                "tx": event:attrs{"bus"}{"Tx"}
            }.klog("subInfo")
        }

        if my_role == "node" && their_role == "node" then noop()

        always {
            ent:seen{sensor_id} := 0
            ent:rumors{sensor_id} := {}
            ent:subscriptions{sensor_id} := subInfo
        }
    }
    
    rule auto_accept { // i am the tx ndoe... put rx node in neighbor...
        select when wrangler inbound_pending_subscription_added
        pre {
            my_role = event:attrs{"Rx_role"}.klog("myrole")
            their_role = event:attrs{"Tx_role"}.klog("theirsrole")
        }

        if my_role == "node" && their_role == "node" then noop()

        fired {
            raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        } else {
            raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }

    // wrangler:subscription? from the node
    // wrangler:new_subscription_request? from the second node... 

    rule gossip_heartbeat {
        select when gossip heartbeat 
        pre {
            subscriber = getPeer(ent:state).klog("sub")// getPeer(state)                    
            m = prepareMessage(ent:state, subscriber)       
            // s = send(subscriber, m)     
            // u = update(state)          
            state = ent:state
        }
        if subscriber != null then send(subscriber, m)
        always {
            ent:current_message := ent:current_message.defaultsTo(0) + 1
            ent:state := state // u = update(state)     
            schedule gossip event "heartbeat" at time:add(time:now, {"seconds": heartbeat_period()})
        }
    }

    rule set_period {
        select when gossip new_heartbeat_period
        always {
            ent:heartbeat_period := event:attr("heartbeat_period")
            .klog("Heartbeat period: "); // in seconds

        }
    }

    rule reset_node {
        select when node reset
        always {
            // ...
        }
    }

    rule gossip_rumor {
        //
        // store rumor, in state about outside world
        // 
        select when gossip rumor
        pre {
            rumor = event:attrs{"message"}
            message_id = rumor{"message_id"}
            message_origin_id = rumor{"message_origin_id"}
            // maybe bring out the origin, and the temp, and the timestamp to avoid duplicates...
        }
        always {
            ent:rumors{message_origin_id} := ent:rumors{message_origin_id}.put(message_id, rumor)
        }
    }

    rule gossip_seen {
        //
        // check for rumors the pico knows about that aren't seen
        // send the correct rumors to the person who doesnt know (could send one or all)
        // 
        select when gossip seen
        foreach event:attrs{"message"} setting(node)
        pre {
            sensor = node.keys()
            sequence = node.values() // may be an array,,,
            should_be_sequence = ent:rumors{sensor}.keys() // should return numbers of each message...
            missing_rumors = ent:rumors{sensor} //... grab from correct array index...
        }
        // if sequence != 
        always {
            // for each rumor under, send that rumor...
        }
    }

    /* 
        {
            sensor_id: {
                eci: ...
                state: {
                    from_whom....: id num
                } 
                temp(info we care about): ...
            },
            sensor_id: {
                ....
            }
        }
    */
    /* Rumor Message....
        { // mine
            "SensorID": "BCDA-9876-BCDA-9876-BCDA-9876": { // who the temp comes from
                "originID": "sensorId",    // why do we care who sent the message?
                "messageId": 1...,
                "Temperature": "78",
                "Timestamp": <ISO DATETIME>
            }
        }
        { // sample
            "MessageID": "ABCD-1234-ABCD-1234-ABCD-1234:5",
            "SensorID": "BCDA-9876-BCDA-9876-BCDA-9876",
            "Temperature": "78",
            "Timestamp": <ISO DATETIME>,
        }
    */
    // keep track of lates rumor message and who sent it...
}