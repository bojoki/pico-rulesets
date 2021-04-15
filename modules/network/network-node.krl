ruleset network.node {
    meta {
        name "Network Node"
        description <<
            A ruleset for a node in the gossip protocol
        >>
        author "Forrest Olson"
        shares sensors, subscriptions, getChannel, my_id
        use module io.picolabs.subscription alias subs
        use module io.picolabs.wrangler alias wrangler
        use module temperature_store alias temps
        provides getChannel, my_id, subscriptions
    }
    global {
        sensors = function() { ent:sensors.defaultsTo("no sensors") } // i think i just replaced this with subscriptions

        subscriptions = function() { ent:subscriptions.defaultsTo("no subscriptions") }

        getChannel = function(sensor_id) { ent:subscriptions{sensor_id}{"tx"} }

        my_id = function() { ent:sensor_id }
        
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
    }

    // 

    rule initialize_ruleset {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid

        pre {
            sensor_id = event:attrs{"sensor_id"}
            parent_eci = wrangler:parent_eci()
            wellKnown_eci = subs:wellKnown_Rx(){"id"}
        }

        identify_myself_to_parent(parent_eci, sensor_id, wellKnown_eci)

        always {
            ent:sensor_id := sensor_id
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

}