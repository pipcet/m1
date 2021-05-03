let this_release_date = process.argv[2];
//this_release_date = this_release_date.substr(1, this_release_date.length - 2)
let last_release_date = process.argv[3];
//last_release_date = last_release_date.substr(1, this_release_date.length - 2)
let child_process = require("child_process");
let log = "";
let last_hash = child_process.execSync(`git rev-parse ${last_release_date}`).toString();
while (last_hash.length && last_hash[last_hash.length-1] === "\n")
    last_hash = last_hash.substr(0, last_hash.length-1);
let json = {};
json.tag_name = this_release_date;
json.name = `${this_release_date} (automatic release)`;
json.prelease = true;
let body = `\n\n`;
body += log;
json.body = body;
console.log(JSON.stringify(json));
