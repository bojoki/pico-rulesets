ruleset gossip.node.consolidated {
    meta {
        name "Gossip Node"
        description <<
            A ruleset for a node in the gossip protocol
        >>
        author "Forrest Olson"
        shares heartbeat_period, neighbors, state, seen, rumors, my_id, last_message, last_temp
        use module temperature_store alias temps
        use module gossip.node alias node
    }

    // all my ent vars:
    // ent:last_reported_temp, ent:last_temp_number (if last == 1, ive reported 1 temp...), ent:all_temps
    // ent:rumors, ent:seen, 
    // ent:state (contains all) 

    global {
        heartbeat_period = function() { ent:heartbeat_period.defaultsTo(default_heartbeat_period) };
        default_heartbeat_period = 15; 
        last_temp = function() { ent:last_temp }
        last_message = function() { ent:last_message } 
        next_message = function() { ent:last_message + 1 }
        current_temp = function() { temps:current_temp() }
        rumors = function() { ent:rumors }
        seen = function() { ent:seen }
        getChannel = function(sensor_id) { node:getChannel(sensor_id) }
        my_id = node:my_id()
        neighbors = function() { node:subscriptions().keys() }
        getPeers = function() { 
            // possible_nodes = ent:rumors.filter( function (val, key) { 
            //                     (val.length() <= 0) => val | val.values().any( function(v) { 
            //                         v{"message_id"} != current_message } 
            //                     )
            //                 }).keys().klog("possible: ") // k = mesasge_id
            // node_to_send = possible_nodes[random:integer(possible_nodes.length() - 1)].klog("actual node")
            nodes = neighbors().klog("neighbs: ").map( function(id) { node:getChannel(id) } )
            nodes.klog("nodes to send to:")
        }
        newRumor = function() {
            {
                "origin_id": my_id, // same as temp origin id
                "message_id": ent:last_message, // rather ent:current_message++
                // "temp_origin_id": ent:sensor_id, // either self or some node from a current state, doesnt really matter
                "temperature": current_temp(){"temp"}, // etiher self or some node, current_temp().get("temp")
                "timestamp":  current_temp(){"time"}// either self or some node, current_temp().get("time")
            }
        }
        // prepareMessage = function(type, isNewTemp) {
        //     isNewTemp => newRumor() |  
        //                  (type == "rumor") => oldRumor()  |
        //                                       ent:seen{my_id()}
        // }
        send = defaction(subscriber, type, message) {
            event:send({
                "eci": subscriber,
                "domain": "gossip", "name": type, // message type...
                "attrs": {
                    "message": message, //ent:seen // should be fine?
                    "sensor_id": my_id
                }
            })
        }
        state = function() {
            {
                "seen": ent:seen,
                "rumors": ent:rumors,
                "last_message": ent:last_message,
                "last_temp": ent:last_temp,
                "all_temps": ent:all_temps,
            }
        }
    }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        
        pre{
            sensor_id = event:attrs{"sensor_id"}
        }

        always {
            ent:sensor_id := sensor_id
            ent:seen := {} // {1: {1: 5, 2: ...}, 2: {1: ...}, ....}
            ent:rumors := {} // {1: [rumor1, 2, 3 ...], 2: [...], ....}
            ent:last_message := 1
            ent:all_temps := []
            ent:heartbeat_period := default_heartbeat_period
            ent:seen{my_id} := 0
            raise gossip event "heartbeat"
        }
    }

    rule send_heartbeat {
        select when gossip send_message_to_all_subscribers
        foreach event:attrs{"subscribers"} setting (subscriber)
        pre {
            message = event:attrs{"message"}
            type = event:attrs{"type"}
        }
        send(subscriber, type, message)
    }

    rule gossip_heartbeat {
        select when gossip heartbeat
        // should check to see if heartbeat need updated 
        pre {
            temp = current_temp()
            isNewTemp = (temp != ent:last_temp)
            subscribers = getPeers().klog("subscriber:")             
            message = isNewTemp => newRumor() | ent:seen.klog("seen?:")  // might want to include self to make sure reinitialize..., aside fro mfull network failure...
            type = isNewTemp => "rumor" | "seen"
        }

        always {
            raise gossip event "send_message_to_all_subscribers" attributes {"subscribers":subscribers, "message": message, "type":type}
            ent:last_temp := temp
            ent:all_temps := isNewTemp => ent:all_temps.append(temp) | ent:all_temps
            ent:last_message := isNewTemp => ent:last_message + 1 | ent:last_message
            ent:rumors{my_id} := isNewTemp => ent:rumors{my_id}.append(message) | ent:rumors{my_id}
            ent:seen{my_id} := isNewTemp => ent:last_message | ent:seen{my_id} 
            schedule gossip event "heartbeat" at time:add(time:now, {"seconds": 20})
        }
    }

    rule gossip_rumor {
        //
        // store rumor
        // update seen
        // 
        select when gossip rumor

        pre {
            rumor = event:attrs{"message"}.klog("rumor message received:")
            message_id = rumor{"message_id"}.klog("message id :")
            origin_id = rumor{"origin_id"}.klog("origin id :")
            last_message = ent:seen{origin_id} || 0
            on_track = ((message_id - last_message.klog("last message:")) == 1).klog("ontrack?:")
            isNotDuplicate = ent:rumors{origin_id} => ent:rumors{origin_id}.all( function(x){x != rumor} ) | true
        }

        if isNotDuplicate then noop()

        fired {
            ent:rumors{origin_id} := ent:rumors{origin_id}.append(rumor)
            ent:seen{origin_id} := (on_track => 
                                            message_id | 
                                            last_message).klog("seen should be:")
        }
    }

    rule send_rumeys {
        select when gossip send_all_missing_rumors_to_one_node
        foreach event:attrs{"rumors"} setting (rumor)
        pre {
            message = rumor
            subscriber = getChannel(event:attrs{"sensor_id"})
            type = "rumor"
        }
        send(subscriber, type, message)
    }

    rule gossip_seen { // i think this is good...
        //
        // check for rumors the pico knows about that aren't seen
        // send the correct rumors to the person who doesnt know (could send one or all)
        // (just need one, to check the one that i am...)
        select when gossip seen
        foreach event:attrs{"message"} setting(last_seen_message, from_node)
            // foreach ent:rumors{node.keys().head()}.keys().filter( function(x){x > node.values().head()} ) setting(rumor_id)
        pre {
            // .klog("from this node:")
            // .klog("ive seen these messages:")
            sensor_to_send_to = event:attrs{"sensor_id"}.klog("this node:")
            ls = last_seen_message.klog("has seen these messages:")
            fn = from_node.klog("from this node:")
            // from_node = node_seen_pair.keys().head()
            // last_seen_message = node_seen_pair.values().head()
            add_node = (not (ent:seen.klog("my_seen") >< from_node)) => from_node.klog("is missing:") | null
            missing_messages = add_node => [] | ent:seen{from_node} => ent:rumors.klog("all rumore"){from_node}.klog("eligible rumors").filter( function(rumor) {
                rumor => (rumor.klog("rumor"){"message_id"} > last_seen_message) | false
            }).klog("missing_messages:") | []
            // sensor_id = event
            // message = ent:rumors{sensor_id}{rumor_id}
            // send rumor for each of these sequences...
        }
        
        // send(getChannel(sensor_id), "rumor", message)
        // if sequence != 
        always {
            ent:seen := add_node => ent:seen.put(add_node, 0) | ent:seen 
            raise gossip event "send_all_missing_rumors_to_one_node" 
                    attributes {"sensor_id":sensor_to_send_to, "rumors": missing_messages}
            // for each rumor under, send that rumor...
        }
    }

    rule set_period {
        select when gossip new_heartbeat_period
        always {
            ent:heartbeat_period := event:attrs{"heartbeat_period"}
            .klog("Heartbeat period: "); // in seconds

        }
    }

    rule reset_node {
        select when node reset

        always {
            ent:seen := {}
            ent:rumors := {}
            ent:last_message := 1
            ent:last_temp := null
            ent:all_temps := []
        }
    }
}