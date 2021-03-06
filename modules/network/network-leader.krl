ruleset network.leader {
    meta {
        name "Network Leader"
        description << A pico for creating a network of connected nodes >>
        author "Forrest Olson"
        shares sensors, temperatures, nameFromID, showChildren, profiles, showSubscriptions
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
    }
    global {
        sensors = function() {
            ent:sensors.defaultsTo({})
          }
    
        nameFromID = function(sensor_id) {
            "Sensor " + sensor_id + " Pico"
        }
    
        showChildren = function() {
            wrangler:children()
        }
    
        defaultThresh = function() {
            99
        }
    
        showSubscriptions = function() {
            ent:subs.defaultsTo("No subs yet!")
        }

        install_custom_ruleset = defaction(eci, url, config) {
            event:send(
                { 
                    "eci": eci, 
                    "eid": "install-ruleset", // can be anything, used for correlation
                    "domain": "wrangler", "type": "install_ruleset_request",
                    "attrs": {
                        "url": url,
                        "config": {}
                    }.put(config)
                }
            )
        }

        reset_nodes = defaction(sensor) {
            event:send(
                { 
                    "eci": sensor.get("eci"), "eid": random:word(),
                    "domain": "node", "type": "reset",
                    "attrs": {}
                }
              )
        }

        start_gossip_in_nodes = defaction(sensor) {
            event:send({
                "eci": sensor.get("eci"),
                "domain": "gossip", "name": "heartbeat",
                "attrs": {}
              })
        }

        subscribe = defaction(from, to) {
            event:send({
                "eci": ent:sensors.get([from, "eci"]),
                "domain": "wrangler", "name": "subscription",
                "attrs": {
                  "wellKnown_Tx": ent:sensors.get([to, "wellKnown_eci"]), 
                  "Rx_role":"node", "Tx_role":"node",
                  "name": ent:sensor_id.defaultsTo("newSub").as("String"), "channel_type": "subscription",
                  "rx_node":from, "tx_node":to
                }
              })
        }
    } 

    rule start_heartbeats {
        select when gossip initiate
        foreach ent:sensors setting (sensor)
        start_gossip_in_nodes(sensor)
    }

    rule initialize_ruleset {
        select when ruleset initialize
    }

    rule initialize_sensors {
        select when sensors need_initialization
        always {
          ent:sensors := {}
          ent:subs := {}
        }
    }
       
    rule new_sensor {
        select when sensor new_sensor

        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors && ent:sensors >< sensor_id
        }

        if not exists then noop()

        fired {
            raise wrangler event "new_child_request"
            attributes { "name": nameFromID(sensor_id),
                            "backgroundColor": "#ff69b4",
                            "sensor_id": sensor_id }
        }
    }

    rule unneeded_sensor {
        select when sensor unneeded_sensor

        pre {
            sensor_id = event:attrs{"sensor_id"}
            exists = ent:sensors >< sensor_id
            eci_to_delete = ent:sensors{[sensor_id,"eci"]}
        }

        if exists && eci_to_delete then send_directive("deleting_section", {"sensor_id":sensor_id})

        fired {
            raise wrangler event "child_deletion_request"
            attributes {"eci": eci_to_delete};
            clear ent:sensors{sensor_id}
        }
    }

    rule new_child {
        select when wrangler new_child_created

        pre {
            child_eci = event:attrs{"eci"}
            name = event:attrs{"name"}
            sensor_id = event:attrs{"sensor_id"}
            sensor_details = { "name": name, "eci": child_eci }
            mac = 0
            files = mac => [
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/temperature_store.krl",
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/sensor_profile.krl",
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/twilio_module.krl",
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/wovyn_base.krl",
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/io.picolabs.wovyn.emitter.krl",
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/gossip/gossip-node.krl",
                    "file:///Users/Bojoki/Desktop/BYU 2021 Winter/pico-rulesets/gossip/gossip-consolidated.krl"
                ] | [
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/temperature_store.krl",
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/sensor_profile.krl",
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/twilio_module.krl",
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/wovyn_base.krl",
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets\io.picolabs.wovyn.emitter.krl",
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets\gossip/gossip-node.krl",
                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets\gossip\gossip-consolidated.krl"
                ]
            i = 0 
        }

        every {
            install_custom_ruleset(child_eci,
                files[0],
                {"sensor_id":sensor_id}) // remove config... just append this to call.
            install_custom_ruleset(child_eci,
                files[1],
                {"sensor_id": sensor_id,
                "sensor_collection_wellKnown_eci": subs:wellKnown_Rx(){"id"}})
            install_custom_ruleset(child_eci,
                files[2],
                {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                files[3],
                {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                files[4],
                {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                files[5],
                {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                files[6],
                {"sensor_id": sensor_id})
        }

        always {
            ent:sensors := ent:sensors.defaultsTo({}).put(sensor_id, sensor_details);
        }
    }

    rule accept_wellKnownEci {
        select when sensor identify 
            sensor_id re#(.+)#
            wellKnown_eci re#(.+)#
            setting(sensor_id, wellKnown_eci)
        send_directive("SAY:", "LOGING")
        fired {
            ent:sensors{[sensor_id, "wellKnown_eci"]} := wellKnown_eci
        }
    }

    rule add_subscription {
        select when sensors subscribe

        pre {
            first_node = event:attrs{"first"}
            second_node = event:attrs{"second"}
        }

        subscribe(first_node, second_node)
    }

    rule reset_nodes {
        select when spawner initialize
        foreach ent:sensors setting (sensor)
        reset_nodes(sensor)
    }

}