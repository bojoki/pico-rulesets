ruleset initialize_sensor {
  meta {
    name "Sensor Initializer"
    description << A way to intialize sensors, e.g. steps to complete on creation >>
    author "Forrest Olson"
    // shares sensors, temperatures, nameFromID, showChildren
    // provides
    use module io.picolabs.wrangler alias wrangler
  }
  global {

  }
  rule initialize {
    select when wrangler ruleset_installed where event:attrs{"rids"}[0] == meta:rid
    // select when 
    //   where event:attr("rids") >< meta:rid
    pre {
    //   tags = [meta:rid]
    //   domains = __testing{"events"}
    //     .map(function(e){e.get("domain")})
    //     .unique()
    //     .sort()
    //   eventPolicy = 
    //     { "allow":domains.map(function(d){{"domain":d,"name":"*"}}),
    //       "deny":[]
    //     }
    //   queryPolicy = {"allow":[{"rid":meta:rid,"name":"*"}],"deny":[]}
        // rids = event:attrs{"rids"}
        // channels = event:attrs{"channels"}
        my_eci = event:attrs{"eci"}
        rids = []
        tags = ["all_channel"]
        ep = {"allow":[{"domain":"*", "name":"*"}], "deny":[]}
        qp = {"allow":[{"domain":"*", "name":"*"}], "deny":[]}
    }
    every {
        wrangler:createChannel(tags,eventPolicy,queryPolicy)
        wrangler:createChannel(tags,eventPolicy,queryPolicy)
        // foreach rids setting(rid)
        //     event:send(
        //         { 
        //             "eci": my_eci, "eid": random:word(),
        //             "domain": "wrangler", "type": "install_ruleset_request",
        //             "attrs": {
        //                 "absoluteURL":meta:rulesetURI,
        //                 "rid":rid,
        //                 "config":{},
        //             }
        //         }
        //     )
    }
  }
}