/*
    Copyright (c) 2015, Salesforce.com Foundation
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Salesforce.com Foundation nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Kevin Bromer, Laura Meerkatz
* @date 2015
* @group Github-AA
* @description Supports the unauthenticated Force.com site for receiving Github webhooks
*/
@RestResource(urlMapping='/github/webhook')
global without sharing class GithubWebhookHandler {

  /*******************************************************************************************************
  * @description A wrapper for the ResponseWrapper object that includes the message to be sent
  ********************************************************************************************************/
  global class ResponseWrapper {
      global String message { get; set; }

      global ResponseWrapper(String message) {
          this.message = message;
      }
  }

  /*******************************************************************************************************
  * @description Validates and accepts an HttpPost request to the unauthenticated sites endpoint
  * @return ResponseWrapper
  ********************************************************************************************************/
  @HttpPost
  global static ResponseWrapper receiveEvent() {
      RestRequest req = RestContext.request;
      String body = req.requestBody.toString();

      /* Check the event type and deserialize to the actual type that is created */

      /* Check if either A: This issue is actively being tracked already or B: the user is authenticated & there's a lurch command
      /* or C: The user is authenticated and its an action not requiring a Lurch command (milestone created, labeling, whatever) */
      String github_event_type = req.headers.get('X-GitHub-Event');
      String event_body = '';
      String issue_body = '';
      String event_title = '';
      String event_user = '';
      Integer event_id;
      String event_url = '';
      String event_repo_name = '';
      Integer event_number;
      String event_action = '';

      //need to rename reserved to support the needed number field
      body = Github.renameReserved(body);

      if (github_event_type == 'issue_comment'){
        Github.IssueCommentEvent evt = (Github.IssueCommentEvent) JSON.deserialize(body, Github.IssueCommentEvent.class);
        event_body = evt.comment.body;
        issue_body = evt.issue.body;
        event_title = evt.issue.title; //this is correct
        event_user = evt.comment.user.login;
        event_id = evt.comment.id;
        event_url = evt.comment.html_url;
        event_repo_name = evt.repository.name;
        event_number = evt.issue.num;
        event_action = evt.action;
      }
      else if (github_event_type == 'issues'){
        Github.IssuesEvent evt = (Github.IssuesEvent) JSON.deserialize(body, Github.IssuesEvent.class);
        event_body = evt.issue.body;
        issue_body = evt.issue.body;
        event_title = evt.issue.title;
        event_user = evt.issue.user.login;
        event_id = evt.issue.id;
        event_url = evt.issue.html_url;
        event_repo_name = evt.repository.name;
        event_number = evt.issue.num;
        event_action = evt.action;
      }
      else if (github_event_type == 'pull_request'){
        Github.PullRequestEvent evt = (Github.PullRequestEvent) JSON.deserialize(body, Github.PullRequestEvent.class);
        event_body = evt.pull_request.body;
        issue_body = evt.pull_request.body;
        event_title = evt.pull_request.title;
        event_user = evt.pull_request.user.login;
        event_id = evt.pull_request.id;
        event_url = evt.pull_request.html_url;
        event_repo_name = evt.repository.name;
        event_number = evt.pull_request.num;
        event_action = evt.action;
      }

      ResponseWrapper resp;

      //handle lurch commands
      if (event_body.containsIgnoreCase('**lurch:')) {
        GithubToAgileAccelerator.Action action = GithubToAgileAccelerator.parseAction(event_body);
        String target = '';

        //will throw a null pointer - catch and toss an exception and respond with it
        if (action.type == 'attach'){
          try{
            target = [SELECT id from agf__ADM_Work__c where Name = :action.target].id;
          } catch (Exception e){
            return new ResponseWrapper('Work item not found or query error');
          }
        }

        if (action.type == 'add' || action.type == 'detach' || action.type == 'attach') {
            Github_Request__c gitRequest = new Github_Request__c(
                Action__c = action.type,
                Title__c = event_title,
                Body__c = action.type == 'add' ? issue_body : event_body,
                Status__c = 'New',
                Target__c = action.type == 'attach' ? target : null ,
                Github_Event__c = github_event_type + ' ' + event_action,
                Github_Record_Id__c = String.valueOf(event_id),
                Github_Record_Type__c = github_event_type,
                Github_Record_URL__c = event_url,
                Github_Repository__c = event_repo_name,
                Github_Username__c = event_user,
                Github_Record_Number__c = String.valueOf(event_number),
                JSON__c = body
            );
          insert gitRequest;
          resp = new ResponseWrapper('Request received.');
        } else {
          resp = new ResponseWrapper('Unable to process request.');
        }
      }

      //handle comments on a tracked record
      //throw out anything that doesn't have either a Github link or a Github Request in the queue
      else if (github_event_type == 'issue_comment' && !event_body.containsIgnoreCase('Tracking <a href') &&
              (GithubWebhookHandler.hasGithubLink(event_number, event_repo_name) || GithubWebhookHandler.hasExistingRequestInQueue(event_number))){
        Github_Request__c gitRequest = new Github_Request__c(
            Action__c = 'comment',
            Title__c = event_title,
            Body__c = event_body,
            Comment__c = event_body,
            Status__c = 'New',
            Github_Event__c = github_event_type + ' ' + event_action,
            Github_Record_Id__c = String.valueOf(event_id),
            Github_Record_Type__c = github_event_type,
            Github_Record_URL__c = event_url,
            Github_Repository__c = event_repo_name,
            Github_Username__c = event_user,
            Github_Record_Number__c = String.valueOf(event_number),
            JSON__c = body
        );
        insert gitRequest;
        resp = new ResponseWrapper('Request received.');
      }
      //handle opening/closing of tracked github issue
      else if (github_event_type == 'issues'){
      }
      else {
          resp = new ResponseWrapper('No command received.');
      }
      return resp;
  }

  /*******************************************************************************************************
  * @description Returns true if the IssueCommentEvent has a valid issue already in the queue - NOTE: this is dependent on the insert order (issue->issue_comment) to work correctly
  * @return Boolean
  ********************************************************************************************************/
  private static Boolean hasExistingRequestInQueue(Integer event_num){
    List<Github_Request__c> grList = new List<Github_Request__c>();
    //query for any github requests that are new adds for the same issue as this issue comment
    grList = [select Name, Id from Github_Request__c where Status__c = 'New' and Action__c = 'add' and Github_Record_Number__c = :String.valueOf(event_num)];
    return !grList.isEmpty();
  }

  /*******************************************************************************************************
  * @description Returns true if the IssueCommentEvent has a valid Github link already in the system
  * @return Boolean
  ********************************************************************************************************/
  private static Boolean hasGithubLink(Integer event_num, String event_repo_name){
    List<Github_Link__c> grList = new List<Github_Link__c>();
    String issueUniqueId = GithubToAgileAccelerator.getUniqueId(event_repo_name, String.valueOf(event_num));
    //query for any github requests that are new adds for the same issue as this issue comment
    grList = [select Name, Id from Github_Link__c where GitHub_Unique_Id__c = :issueUniqueId];
    return !grList.isEmpty();
  }
}
