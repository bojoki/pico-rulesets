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
        threshold_temp = 72

        getPeers = function() { 
            nodes = neighbors().klog("neighbs: ").map( function(id) { node:getChannel(id) } )
            nodes.klog("nodes to send to:")
        }

        newRumor = function() {
            {
                "origin_id": my_id, 
                "message_id": ent:last_message, 
                "temperature": current_temp(){"temp"}, 
                "timestamp":  current_temp(){"time"}, 
                "violations": ent:violated
            }
        }
        
        send = defaction(subscriber, type, message) {
            event:send({
                "eci": subscriber,
                "domain": "gossip", "name": type,
                "attrs": {
                    "message": message, 
                    "sensor_id": my_id
                }
            })
        }

        state = function() {
            {
                "seen": ent:seen,
                "rumors": ent:rumors,
                "last_message": ent:last_message - 1,
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
            ent:violated := -1
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
        
        pre {
            temp = current_temp()
            violation = temp{"temp"}.klog("temp") > threshold_temp.klog("thresh")
            isNewTemp = (temp != ent:last_temp)
            subscribers = getPeers().klog("subscriber:")             
            type = isNewTemp => "rumor" | "seen"
        }

        if temp.klog("the temp!") != "no temp rn" then noop()

        fired {
            ent:violated := isNewTemp.klog("newtemp?:") => (violation.klog("violation?:") =>  ((ent:violated.klog("old") == -1) => 1 | 0).klog("idk") | -1) | ent:violated.klog("oldviolted:")
            message = isNewTemp => newRumor() | ent:seen.klog("seen?:")
            raise gossip event "send_message_to_all_subscribers" attributes {"subscribers":subscribers, "message": message, "type":type}
            ent:last_temp := temp
            ent:all_temps := isNewTemp => ent:all_temps.defaultsTo([]).append(temp) | ent:all_temps
            ent:rumors{my_id} := isNewTemp => ent:rumors{my_id}.defaultsTo([]).append(message) | ent:rumors{my_id}
            ent:seen{my_id} := isNewTemp => ent:last_message | ent:seen{my_id} 
            ent:last_message := isNewTemp => ent:last_message + 1 | ent:last_message
            schedule gossip event "heartbeat" at time:add(time:now, {"seconds": 20})
        } else {
            schedule gossip event "heartbeat" at time:add(time:now, {"seconds": 20})
        }
    }

    rule gossip_rumor {
        select when gossip rumor

        pre {
            rumor = event:attrs{"message"}.klog("rumor message received:")
            message_id = rumor{"message_id"}.klog("message id :")
            origin_id = rumor{"origin_id"}.klog("origin id :")
            last_message = ent:seen{origin_id} || 0
            on_track = ((message_id - last_message.klog("last message:")) == 1).klog("ontrack?:")
            isNotDuplicate = (ent:rumors{origin_id} => ent:rumors{origin_id}.all( function(x){x != rumor} ) | true).klog("duplicate?:")
        }

        if isNotDuplicate then noop()

        fired {
            ent:rumors{origin_id} := ent:rumors{origin_id}.defaultsTo([]).append(rumor)
            ent:seen{origin_id} := (on_track => 
                                            message_id | 
                                            last_message).klog("seen should be:")
        } else {
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

    rule gossip_seen {
        select when gossip seen
        foreach event:attrs{"message"} setting(last_seen_message, from_node)
        
        pre {
            sensor_to_send_to = event:attrs{"sensor_id"}.klog("this node:")
            ls = last_seen_message.klog("has seen these messages:")
            fn = from_node.klog("from this node:")
            add_node = (not (ent:seen.klog("my_seen") >< from_node)) => from_node.klog("is missing:") | null
            missing_messages = add_node => [] | ent:seen{from_node} => ent:rumors.klog("all rumore"){from_node}.klog("eligible rumors").filter( function(rumor) {
                rumor => (rumor.klog("rumor"){"message_id"} > last_seen_message) | false
            }).klog("missing_messages:") | []
        }

        always {
            ent:seen := add_node => ent:seen.put(add_node, 0) | ent:seen 
            raise gossip event "send_all_missing_rumors_to_one_node" 
                    attributes {"sensor_id":sensor_to_send_to, "rumors": missing_messages}
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
            ent:violated := -1
        }
    }

}