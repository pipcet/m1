let this_release_date = process.argv[2];
//this_release_date = this_release_date.substr(1, this_release_date.length - 2)
let last_release_date = process.argv[3];
//last_release_date = last_release_date.substr(1, this_release_date.length - 2)
let child_process = require("child_process");
let log = "";
let logh = child_process.execSync(`git log ${last_release_date}..HEAD --pretty=format:'%H %s'`).toString() || "no changes";
{
    for (let line of logh.split("\n")) {
	let hash = line.substr(0, 40);
	let body = child_process.execSync(`git log -1 ${hash} --pretty=format:'%b'`).toString();
	log += line + "\n" + (body && ("\n" + body + "\n"));
    }
}
let last_hash = child_process.execSync(`git rev-parse ${last_release_date}`).toString();
while (last_hash.length && last_hash[last_hash.length-1] === "\n")
    last_hash = last_hash.substr(0, last_hash.length-1);
let json = {};
json.tag_name = this_release_date;
json.name = `${this_release_date} (automatic release)`;
json.prelease = true;
let body = `Changes since ${last_release_date} (${last_hash}):\n\n`;
body += log;
json.body = body;
console.log(JSON.stringify(json));
