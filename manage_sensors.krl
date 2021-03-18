ruleset manage_sensors {
  meta {
    name "Sensor Manager"
    description << A way to manage sensors, i.e. creation, deletion, update.... >>
    author "Forrest Olson"
    shares sensors, temperatures, nameFromID, showChildren, profiles, latestReports, reportNum
    use module io.picolabs.wrangler alias wrangler
  }
   
  global {
    sensors = function() {
      ent:sensors.defaultsTo({})
    }

    temperatures = function() {
      sensors().map(function(v, k)  { 
        wrangler:picoQuery(v.get("eci"), "temperature_store", "temperatures", {}.put())
      })
    }

    profiles = function() {
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
    reportNum = function() {
      ent:reportNum.defaultsTo(1)
    }
    // reports = function() {
    //   ent:reports.defaultsTo("No reports for reporting")
    // }
    latestReports = function() {
      ent:reports.defaultsTo("No reports for reporting").filter(function(v, k){ 
        k >= (ent:reportNum.defaultsTo(1) - 5)
      })
    }
  }

  rule initialize_sensors {
    select when sensors need_initialization
    always {
      ent:sensors := {}
    }
  }

  rule initialize_report {
    select when report needs_initialization
    always {
      ent:reportNum := 1
      ent:reports := {}
    }
  }
   
  rule new_sensor {
    select when sensor new_sensor
    pre {
      sensor_id = event:attrs{"sensor_id"}
      exists = ent:sensors && ent:sensors >< sensor_id
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

  rule initiate_report {
    select when report initiate
    pre {
      new_report = {"temperature_sensors": ent:sensors.length(), 
                    "responding" : ent:sensors.length(),
                    "temperatures" : []}
      
    }
    
    send_directive("you dont say?", "reporting!")

    fired {
      raise report event "for_each_sensor" attributes {
        "reportNum": ent:reportNum.defaultsTo(1)
        }

      ent:reports := ent:reports.defaultsTo({}).put(ent:reportNum.defaultsTo(1), new_report)
      ent:reportNum := ent:reportNum.defaultsTo(1) + 1
    }
  }

  rule for_each_sensor {
    select when report for_each_sensor
    foreach ent:sensors setting (sensor)
      pre {
        parent_eci = wrangler:children().filter(function(child) {
          child.get("eci") == sensor.get("eci")
        }).klog("now?").head().get("parent_eci").klog("parentECI?")
        // .get("parent_eci")
      }
      event:send(
        { 
            "eci": sensor.get("eci"), "eid": random:word(),
            "domain": "report", "type": "request",
            "attrs": {
                "reportId": event:attrs{"reportNum"},
                "parentEci": parent_eci,
                "childEci" : sensor.get("eci")
            }
        }
      )
  }

  rule receive_report {
    select when report result
    // {<report_id>: {"temperature_sensors" : 4,
    //               "responding" : 4,
    //               "temperatures" : [<temperature reports from sensors>]
    //              }
    pre {
      reportId = event:attrs{"reportId"}.klog("reportid")
      result = event:attrs{"reportTemp"}
      reports = ent:reports.defaultsTo({})
      old_report = reports.get([reportId]).klog("old report")
      old_num_sens = old_report.get("temperature_sensors")
      old_temps = old_report.get(["temperatures"])
      old_responding = old_report.get("responding")
      new_report = {
                    "temperature_sensors": old_num_sens, 
                    "responding": (old_responding - 1), 
                    "temperatures": old_temps.klog("oldTemps").append(result).klog("new Temps")
                  }
    }

    send_directive("reported", event:attrs)

    always {
      ent:reports := reports.put([event:attrs{"reportId"}], new_report)
    }

  }   
}