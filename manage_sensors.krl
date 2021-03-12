ruleset manage_sensors {
  meta {
    name "Sensor Manager"
    description << A way to manage sensors, i.e. creation, deletion, update.... >>
    author "Forrest Olson"
    shares sensors, temperatures, nameFromID, showChildren, profiles
    use module io.picolabs.wrangler alias wrangler
  }
   
  global {
    // 6. 
    // Write a function in the manage_sensors ruleset called sensors that returns the child pico information 
    // (which should be in the entity variable you created above).
    sensors = function() {
      ent:sensors.defaultsTo({})
    }

    // 9.
    // Write a function in the manage_sensors ruleset that calls the temperatures function in each of the sensors it knows about. 
    // The result should be a JSON object combining the results returned by each sensor. 
    // Be sure that the function continues to work even when sensors are added or deleted. 
    temperatures = function() {
      // for each child
      // append temperatures to result
      // {}.toJson();
      sensors().map(function(v, k)  { 
        wrangler:picoQuery(v.get("eci"), "temperature_store", "temperatures", {}.put())
      })
    }

    profiles = function() {
      // for each child
      // append temperatures to result
      // {}.toJson();
      sensors().map(function(v, k)  { 
        wrangler:picoQuery(v.get("eci"), "sensor_profile", "sensor_info", {}.put())
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

  }

  rule initialize_sensors {
    select when sensors need_initialization
    always {
      ent:sensors := {}
    }
  }
   
  rule new_sensor {
    select when sensor new_sensor
    // 3. 
    // Write a rule in the manage_sensors ruleset that responds to a sensor:new_sensor event by 
    // 1. programmatically creating a new pico to represent the sensor
    // 2. installing the temperature_store, wovyn_base, sensor_profile, and io.picolabs.wovyn.emitter rulesets in the new sensor. 
    // 3. storing the value of an event attribute giving the sensor's name and the new sensors pico's ECI in an entity variable called sensors that maps its name to the ECI
    pre {
      sensor_id = event:attrs{"sensor_id"}
      exists = ent:sensors && ent:sensors >< sensor_id
      // 5.
      // Modify the rule for creating a new sensors to not allow duplicate names.
      // sensor_location = event:attrs{"location"}.klog("your passed in location: ")
      // sensor_name = event:attrs{"name"}.klog("your passed in name: ")
      // threshold_temp = event:attrs{"threshold"}.klog("your passed in threshold temp: ")
      // contact_number = event:attrs{"contact"}.klog("your passed in number: ")
    }
    //action
    // send_directive("info", {"old_info": sensor_info(), "new_info": get_info(sensor_location, sensor_name, contact_number, threshold_temp)})
    if not exists then noop()
    fired {
      raise wrangler event "new_child_request"
        attributes { "name": nameFromID(sensor_id),
                     "backgroundColor": "#ff69b4",
                     "sensor_id": sensor_id }
    }
      // ent:sensor_name := sensor_name
      // ent:sensor_location := sensor_location
      // ent:threshold_temp := threshold_temp
      // ent:contact_number := contact_number
      // 4.
      // Programmatically send a sensor:profile_updated event to the child after it's created to set its name, notification SMS number, and default threshold. 
      // The name should be an attribute of the sensor:new_sensor event and the threshold should be a default value defined in the manage_sensors ruleset. 
      // You'll need to avoid race conditions so that you're not trying to update the profile before the system has finished creating the child and installing the desired rulesets.
  }



  rule unneeded_sensor {
    select when sensor unneeded_sensor
    // 7. 
    // Write a rule that responds to a sensor:unneeded_sensor event by 
    // 1. programmatically deleting the appropriate sensor pico (identified by an event attribute)
    // 2. removes the mapping in the entity variable for this sensor
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
      // {
      //   // attributes provided by wrangler
      //   "eci": <new child's family eci>,
      //   // attributes you provided in the child_creation request, passed through
      //   "name": <the original provided name YOU gave>,
      //   "backgroundColor": <your provided color string>,
      //   "section_id": <section_id you provided>
      // }

    }
    every {
      // wrangler:createChannel(tags,eventPolicy,queryPolicy)
      // asdf
      event:send(
        { "eci": child_eci, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "url": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\twilio_module.krl",
            // "rid": "twilio_module",
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
            // "rid": "temperature_store",
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
            // "absoluteURL": meta:rulesetURI,
            "url": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\wovyn_base.krl",
            // "rids": "temperature_store",
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
            "absoluteURL": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets/",
            // "url": "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\sensor_profile.krl",
            "rid": "sensor_profile",
            // "rid": "temperature_store",
            // "rid": "sensor_profile",
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
            // "absoluteURL": "file:///C:/Users/forrest.olson/AppData/Roaming/npm/node_modules/pico-engine/krl",
            "url" : "file://C:\Users\forrest.olson\Desktop\forrest\pico-rulesets\io.picolabs.wovyn.emitter.krl",
            // "rid": "io.picolabs.wovyn.emitter",
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
    select when wrangler ruleset_installed
    pre {

    }
    always {

    }
  }
// 8.
// Write a script or test harness to test your set up. Ensure your test harness tests the rules and functions you defined by:
// 1. creating multiple sensors and deleting at least one sensor. You only have one Wovyn device, so you'll only have one sensor pico that is actually connected to a device, the others will have the emitter simulator ruleset. Note: you'll have to reprogram the Wovyn sensor to send events to the new pico instead of the one you created manually and pause the emitter ruleset in that pico so it's not also firing. 
// 2. tests the sensors by ensuring they respond correctly to new temperature events. 
// 3. tests the sensor profile to ensure it's getting set reliably.
   

}