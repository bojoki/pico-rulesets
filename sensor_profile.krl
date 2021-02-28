ruleset sensor_profile {
  meta {
    name "Sensor Profile"
    description <<
A ruleset for creating a sensor profile
>>
    author "Forrest Olson"
    shares contact_number, threshold_temp, sensor_location, sensor_name, sensor_info
  }
   
  global {
    sensor_info = function() {
      {"location":sensor_location(), "name":sensor_name(), "contact":contact_number(), "threshold":threshold_temp()}
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
   

}