ruleset sensor_profile {
  meta {
    name "Sensor Profile"
    description <<
A ruleset for creating a sensor profile
>>
    author "Forrest Olson"
    shares contact_number, threshold_temp, sensor_location, sensor_name, sensor_info, sensor_id
    use module io.picolabs.subscription alias subs
    use module io.picolabs.wrangler alias wrangler
    use module temperature_store alias temps
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

  rule make_subscription {
    select when sensor new_subscription_request
    event:send({
      "eci": ent:sensor_collection_wellKnown_eci,
      "domain": "wrangler", "name": "subscription",
      "attrs": {
        "wellKnown_Tx": subs:wellKnown_Rx(){"id"}, // should this be the sensor or the collector?
        "Rx_role":"manager", "Tx_role":"sensor",
        "name": ent:sensor_id.defaultsTo("newSub").as("String"), "channel_type": "subscription"
      }
    })
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      my_role = event:attrs{"Rx_role"}
      their_role = event:attrs{"Tx_role"}
    }
    if my_role == "sensor" && their_role == "manager" then noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
      ent:subscriptionTx:= event:attrs{"Tx"}
    } else {
      raise wrangler event "inbound_rejection"
        attributes event:attrs
    }
  }

  rule send_report {
    select when report request


    event:send({
      "eci": event:attrs{"parentEci"},
      "domain": "report", "name": "result",
      "attrs": {
        "reportTemp": temps:current_temp(),
        "returnEci": event:attrs{"childEci"},
        "reportId": event:attrs{"reportId"}
      }
    })
    
  }
}