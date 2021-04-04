ruleset temperature_store {
  meta {
    name "Temp Store"
    description << A ruleset for storing temperatures >>
    author "Forrest Olson"
    provides temperatures, threshold_violations, inrange_temperatures, current_temp
    shares temperatures, threshold_violations, inrange_temperatures, current_temp, temperature_threshold
  }
   
  global {
    temperature_threshold = function() {
      response = http:get(<<http://localhost:3000/sky/cloud/ckko8h61t000eqstzf1fg8lfo/sensor_profile/threshold_temp>>)
      response{"content"}.decode(){"content"}
    }
    current_temp = function() {
      ent:current_temp.defaultsTo("no temp rn")
    }
    temperatures = function() {
      ent:temperatures.defaultsTo("No temps rn");
    }
    threshold_violations = function() {
      ent:threshold_violations.defaultsTo("No violations rn");
    }
    inrange_temperatures = function () {
      (ent:temperatures) => 
      ent:temperatures.filter(function(v) {
        not ent:threshold_violations.any(function(x){
          x == v // for each temperature read, if matches in threshold violations, reject
        })
      }) | null;
    }

  }
   
  rule collect_temperatures {
    select when wovyn new_temperature_reading

    pre {
      temp1 = event:attrs{"temperature"}[0].klog("new temp") || none
      tempF = temp1{"temperatureF"}.klog("F temp") || none
      tempC = temp1{"temperatureC"}.klog("C temp") || none
      tempTime = event:attrs{"timestamp"}.klog("time of temp") || none
      mappy = {"temperature": temp1, "timestamp": tempTime}
    }

    send_directive("temp_reading", mappy)
   
    always {
      ent:current_temp := { "temp":tempF, "time":tempTime }
      ent:temperatures := ent:temperatures.defaultsTo([]).append(mappy)
      raise wovyn event "threshold_violation" attributes mappy if tempF > temperature_threshold
      // .put("fTemp", tempF).put("cTemp", tempC)
    }

  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation

    pre {
      temp1 = event:attrs{"temperature"}.klog("new temp") || none
      tempF = temp1{"temperatureF"}.klog("F temp") || none
      tempC = temp1{"temperatureC"}.klog("C temp") || none
      timestamp = event:attrs{"timestamp"}.klog("time of temp") || none
      mappy = {"temperature": temp1, "timestamp": timestamp}
    }

    send_directive("temp_violation", mappy)

    always {
      ent:threshold_violations := ent:threshold_violations.defaultsTo([]).append(mappy)
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset

    pre {}

    send_directive("temp_reset", "clearing ...")

    always {
      ent:threshold_violations := []
      ent:temperatures := []
    }
  }

}