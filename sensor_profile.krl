ruleset sensor_profile {
  meta {
    name "Sensor Profile"
    description <<
A ruleset for creating a sensor profile
>>
    author "Forrest Olson"
    shares set_contact_number, set_threshold_temp 
  }
   
  global {
    set_contact_number = function(number) {
      contact_number = number;
      contact_number
    }
    set_threshold_temp = function(temp) {
      threshold_temp = temp;
      threshold_temp
    }
    get_contact_number = function() {
      contact_number
    }
    get_threshold_temp = function() {
      threshold_temp
    }
    contact_number = 14357549364
    threshold_temp = 70
  }
   
  rule profile_updated {
    select when sensor profile_updated
    pre {
      sensor_location = event:attrs{"location"}.klog("your passed in name: ")
      sensor_name = event:attrs{"name"}.klog("your passed in name: ")
    }
    //action
    send_directive("say", {"something": "Hello " + name})
    always {
      ent:sensor_name := sensor_name
      ent:sensor_location := sensor_location
    }
  }
   

}