global with sharing class GithubToAgileAccelerator {
	//lurch.processGithubEvent = function (event_name, event_id, event_body) {
    /*only listen and forward:
    1.  anything with **lurch:add from a known user
    2.  anything with **lurch:attach w-xxxxxxxxxxxx or epic:XXXXXXX from a known user
    3.  anything with **lurch:remove from a known user
    4.  anything currently being actively tracked, regardless of user
    5.  pull requests from a known user
    (?) 5.  milestones
    */

    global static Id addWorkRecord(Github.IssueCommentEvent evt){

        return null;
    }

    global static Id attachToWorkRecord(Github.IssueCommentEvent evt, String workName){

        return null;
    }

    global static Id attachToEpicRecord(Github.IssueCommentEvent evt, String epicName){

        return null;
    }

    global static Id detachFromAllRecords(Github.IssueCommentEvent evt){

        return null;
    }
}