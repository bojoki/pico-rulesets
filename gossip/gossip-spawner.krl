ruleset gossip.spawner {
    meta {
        name "Sensor Manager w/ Subscriptions"
        description << A way to manage sensors, for implementing gossip >>
        author "Forrest Olson"
        shares sensors, temperatures, nameFromID, showChildren, profiles, showSubscriptions
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
    }
    global {
        sensors = function() {
            ent:sensors.defaultsTo({})
          }
      
        temperatures = function() {
            sensors().map(function(v, k)  { 
                wrangler:picoQuery(v.get("sub_rx_channel"), "temperature_store", "temperatures", {}.put())
            })
        }
    
        profiles = function() {
            sensors().map(function(v, k)  { 
                wrangler:picoQuery(v.get("sub_rx_channel"), "sensor_profile", "sensor_info", {}.put())
            })
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
        if exists && eci_to_delete then
            send_directive("deleting_section", {"sensor_id":sensor_id})
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
        }
        every {
            install_custom_ruleset(child_eci,
                                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/temperature_store.krl",
                                    {"sensor_id":sensor_id}) // remove config... just append this to call.
            install_custom_ruleset(child_eci,
                                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/sensor_profile.krl",
                                    {"sensor_id": sensor_id,
                                    "sensor_collection_wellKnown_eci": subs:wellKnown_Rx(){"id"}})
            install_custom_ruleset(child_eci,
                                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/twilio_module.krl",
                                    {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets/wovyn_base.krl",
                                    {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                                    "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets\io.picolabs.wovyn.emitter.krl",
                                    {"sensor_id": sensor_id})
            install_custom_ruleset(child_eci,
                "file://C:\Users\forrest.olson\Desktop\forrest\Picos\pico-rulesets\gossip/gossip-node.krl",
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
        event:send({
            "eci": ent:sensors.get([first_node, "eci"]),
            "domain": "wrangler", "name": "subscription",
            "attrs": {
              "wellKnown_Tx": ent:sensors.get([second_node, "wellKnown_eci"]), 
              "Rx_role":"node", "Tx_role":"node",
              "name": ent:sensor_id.defaultsTo("newSub").as("String"), "channel_type": "subscription"
            }
          })
    }
}