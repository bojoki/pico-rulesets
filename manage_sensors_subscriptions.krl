ruleset manage_sensors_subscriptions {
  meta {
    name "Sensor Manager w/ Subscriptions"
    description << A way to manage sensors, i.e. creation, deletion, update.... >>
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
      event:send(
        { "eci": child_eci, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets/",
            "rid": "sensor_profile",
            "config": {},
            "sensor_id": sensor_id,
            "sensor_collection_wellKnown_eci": subs:wellKnown_Rx(){"id"}
          }
        }
      )
      event:send(
        { "eci": child_eci, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "url": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\twilio_module.krl",
            "config": {},
            "sensor_id": sensor_id
          }
        }
      )
      
      event:send(
        { "eci": child_eci, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "url": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\temperature_store.krl",
            "config": {},
            "sensor_id": sensor_id
          }
        }
      )
      event:send(
        { "eci": child_eci, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "url": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\wovyn_base.krl",
            "config": {},
            "sensor_id": sensor_id
          }
        }
      )
  
      event:send(
        { "eci": child_eci, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "url" : "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\io.picolabs.wovyn.emitter.krl",
            "config": {},
            "sensor_id": sensor_id
          }
        }
      )
      event:send(
        { "eci": child_eci, 
          "eid": "update_profile", // can be anything, used for correlation
          "domain": "sensor", "type": "profile_updated",
          "attrs": {
            "absoluteURL": "file:///C:/Users/forrest.olson/AppData/Roaming/npm/node_modules/pico-engine/krl",
            // "url" : "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl",
            "rid": "io.picolabs.wovyn.emitter",
            "config": {},
            "name": name,
            "threshold": defaultThresh(),
            "sensor_id": sensor_id
          }
        }
      )
    }

    always {
      ent:sensors := ent:sensors.defaultsTo({}).put(sensor_id, sensor_details);
    }
  }

  rule new_ruleset {
    select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
    pre {

    }
    always {

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

  // rule auto_accept {
  //   select when wrangler inbound_pending_subscription_added
  //   pre {
  //     my_role = event:attrs{"Rx_role"}
  //     their_role = event:attrs{"Tx_role"}
  //   }
  //   if my_role == "manager" && their_role == "sensor" then noop()
  //   fired {
  //     raise wrangler event "pending_subscription_approval"
  //       attributes event:attrs
  //     ent:subscriptionTx:= event:attrs{"Tx"}
  //   } else {
  //     raise wrangler event "inbound_rejection"
  //       attributes event:attrs
  //   }
  // }
}