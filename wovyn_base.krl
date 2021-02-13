ruleset wovyn_base {
    meta {
      name "Wovyn Base"
      description << Ruleset for Wovyn devices >>
      author "Forrest Olson"
      shares hello

      use module my.twilio alias twilio 
      with 
        apiToken = meta:rulesetConfig{"apiToken"}
        apiSid = meta:rulesetConfig{"apiSid"}
        apiPhone = meta:rulesetConfig{"apiPhone"}
    }
     
    global {
      hello = function(obj) {
        msg = "Hello " + obj;
        msg
      }
      temperature_threshold = 70
      my_phone = "14357549364"
      current_temp = function(time, tF, tC) {
        8.chr() + 10.chr() + 10.chr() + "        |Weather Report|

Date: " + format_date(time) + "
Time: " + format_time(time) + "
F: " + tF + "°
C: " + tC + "°

Enjoy the fresh new day!" //+ 8.chr() + 10.chr() if blank space is needed after
      }
      format_timestamp = function (time) {
        format_date(time) + " " + format_time(time)
      }
      format_date = function (time) {
        time:strftime(time, "%A, %b %e, %Y") 
      }

      // # Monday, October 6, 2010

      // # Mon, Oct 6, 2010

      // # Monday Oct 6, 2010

      // # Mon Oct 6, 2010
      format_time = function (time) {
        time:strftime(time, "%r") 
      }
    }
     
    rule process_heartbeat {
      select when wovyn heartbeat
      pre {
        genericThing = event:attrs{"genericThing"}.klog("passed in genericThing: ") || none
      }
      //action
      if genericThing then 
        send_directive("say", {"something": "Hello " + genericThing})

      fired {
        // time:new("8:00:00") time:now() event:attr("timestamp")
        raise wovyn event "new_temperature_reading" attributes {"temperature" : genericThing{"data"}{"temperature"}, "timestamp": time:now({"tz" : "MST"})}
      }
  
    }

    // rule find_high_temps {
    //   select when wovyn new_temperature_reading

    //   pre {
    //     temp1 = event:attrs{"temperature"}[0].klog("new temp") || none
    //     tempF = temp1{"temperatureF"}.klog("F temp") || none
    //     tempC = temp1{"temperatureC"}.klog("C temp") || none
    //     tempTime = event:attrs{"timestamp"}.klog("time of temp") || none
    //   }

    //   send_directive("say", {"temp": temp1, "time": tempTime})
     
    //   always {
    //     raise wovyn event "threshold_violation" attributes {}.put("time", tempTime).put("fTemp", tempF).put("cTemp", tempC) if tempF > temperature_threshold
    //   }

    // }

    // rule threshold_notification {
    //   select when wovyn threshold_violation

    //   pre {
    //     tempF = event:attrs{"fTemp"}.klog("new temp") || none
    //     tempC = event:attrs{"cTemp"}.klog("new temp") || none
    //     timestamp = event:attrs{"time"}.klog("time of temp") || none
    //   }

    //   twilio:sendMessage(my_phone, current_temp(timestamp, tempF, tempC)) setting (response)

    //   fired {
    //     raise http event "post" attributes {}.put("response", response)
    //   }
    // }

    // rule test_send {
    //   select when test send
  
    //   pre {
    //     mess = event:attrs{"message"}
    //   }
  
    //   twilio:sendMessage("14357549364", mess) setting(response)
  
    //   fired {
    //     raise http event "post" attributes {}.put("response", response)
    //   }
    // }
  
  }