ruleset gossip.node {
    meta {
        name "Gossip Node"
        description <<
            A ruleset for a node in the gossip protocol
        >>
        author "Forrest Olson"
        shares contact_number, threshold_temp, sensor_location, sensor_name, sensor_info, sensor_id
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
    }
    global {
        sensor_info = function() {
            {
                "location":sensor_location(), 
                "name":sensor_name(), 
                "contact":contact_number(), 
                "threshold":threshold_temp(), 
                "id": sensor_id(),
                "sensor_collection_wellKnown_eci": ent:sensor_collection_wellKnown_eci.defaultsTo("no subscription")
            }
        }
        get_info = function(loc, name, cont, thresh) {
            {"location":loc, "name":name, "contact":cont, "threshold":thresh}
        }
        sensor_location = function() {
            ent:sensor_location.defaultsTo("here")
        }
        sensor_name = function() {
            ent:sensor_name.defaultsTo("wovyn-temp")
        }
        contact_number = function() {
            ent:contact_number.defaultsTo(14357549364)
        }
        threshold_temp = function() {
            ent:threshold_temp.defaultsTo(70)
        }
        sensor_id = function() {
            ent:sensor_id.defaultsTo("no id")
        }
    }

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid

        pre {
            sensor_id = event:attrs{"sensor_id"}
            parent_eci = wrangler:parent_eci()
            wellKnown_eci = subs:wellKnown_Rx(){"id"}
            sensor_collection_wellKnown_eci = event:attrs{"sensor_collection_wellKnown_eci"}
        }
        event:send({
            "eci":parent_eci,
            "domain": "sensor", "type": "identify",
            "attrs": {
            "sensor_id": sensor_id,
            "wellKnown_eci": wellKnown_eci
            }
        })
        always {
            ent:sensor_collection_wellKnown_eci := sensor_collection_wellKnown_eci
            ent:sensor_id := sensor_id
            raise sensor event "new_subscription_request"
        }
    }

    rule profile_updated {
        select when sensor profile_updated
        pre {
            sensor_location = event:attrs{"location"}.klog("your passed in location: ")
            sensor_name = event:attrs{"name"}.klog("your passed in name: ")
            threshold_temp = event:attrs{"threshold"}.klog("your passed in threshold temp: ")
            contact_number = event:attrs{"contact"}.klog("your passed in number: ")
        }
        //action
        send_directive("info", {"old_info": sensor_info(), "new_info": get_info(sensor_location, sensor_name, contact_number, threshold_temp)})
        always {
            ent:sensor_name := sensor_name
            ent:sensor_location := sensor_location
            ent:threshold_temp := threshold_temp
            ent:contact_number := contact_number
        }
    }
    

    // rule make_subscription {
    //     select when sensor new_subscription_request
    //     event:send({
    //         "eci": ent:sensor_collection_wellKnown_eci,
    //         "domain": "wrangler", "name": "subscription",
    //         "attrs": {
    //         "wellKnown_Tx": subs:wellKnown_Rx(){"id"}, // should this be the sensor or the collector?
    //         "Rx_role":"manager", "Tx_role":"sensor",
    //         "name": ent:sensor_id.defaultsTo("newSub").as("String"), "channel_type": "subscription"
    //         }
    //     })
    // }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            my_role = event:attrs{"Rx_role"}.klog("myrole")
            their_role = event:attrs{"Tx_role"}.klog("theirsrole")
        }
        if my_role == "node" && their_role == "node" then noop()
        fired {
            raise wrangler event "pending_subscription_approval"
            attributes event:attrs
            ent:subscriptionTx:= event:attrs{"Tx"}
        } else {
            raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }

    rule add_subscription {
        select when wrangler subscription_added
        pre {
            subID = event:attrs{"Id"}                // The ID of the subscription is given as an attribute
            subInfo = event:attrs{"bus"}             // The relevant subscription info is given in the "bus" attribute // duplicat info
            sensor_id = event:attrs{"name"}
        }
        send_directive("attrs", event:attrs)
        always {
            ent:sensors{[sensor_id, "sub_id"]} := subID
            ent:sensors{[sensor_id, "sub_rx_channel"]} := subInfo.get("Tx")
            ent:subs{subID} := subInfo.put("sensor_id", sensor_id)              // Record the sub info in this ruleset so we can use it
        }
    }
}