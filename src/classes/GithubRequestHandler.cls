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
* @author Kevin Bromer
* @date 2015
* @group Github-AA
* @description Schedulable class that processes the Github Request that are valid posts from the web hook
*/
global without sharing class GithubRequestHandler implements Schedulable {

  /*******************************************************************************************************
  * @description Standard Apex Schedulable execute() method - required to implement the Schedulable interface
  * @param sc the SchedulableContext provided from the calling method
  ********************************************************************************************************/
  global void execute(SchedulableContext sc) {
      processRequests();
  }

  /*******************************************************************************************************
  * @description Processing loop for all Github_Request__c objects currently unhandled in teh system  
  ********************************************************************************************************/
  global void processRequests() {
      // action => list of requests
      // i.e. add => list of requests to add
      Map<String, List<Github_Request__c>> requestsByAction = new Map<String, List<Github_Request__c>>();

      // github record id => last action listed on that Id
      Map<String, String> lastAction = new Map<String, String>();
      List<GitHub_Link__c> processedLinks = new List<GitHub_Link__c>();

      for (Github_Request__c githubRequest :
          [ SELECT Id, Body__c, Title__c, Comment__c, Action__c, Target__c,
              Github_Record_Id__c, Github_Record_Type__c, Github_Record_URL__c,
              Github_Repository__c, Github_Username__c, Status__c, Github_Unique_Id__c,
              Github_Record_Number__c
              FROM Github_Request__c
              WHERE Status__c = 'New'
              ORDER BY CreatedDate
          ]) {

          // add to action map
          if (requestsByAction.get(githubRequest.Action__c) == null) {
              requestsByAction.put(githubRequest.Action__c, new List<Github_Request__c>{ githubRequest });
          } else {
              requestsByAction.get(githubRequest.Action__c).add(githubRequest);
          }
          lastAction.put(githubRequest.Github_Unique_Id__c, githubRequest.Action__c);
      }

      // NOTE: if the same record shows up in the same batch multiple times, only the last action should be honored
      // Processing order is important. adds and attaches must happen before comments to validate the comments

      // process all the adds
      if (requestsByAction.get('add') != null) {
          List<Github_Request__c> requestsToAdd = requestsByAction.get('add');
          requestsByAction.put('add', GithubToAgileAccelerator.addWorkRecords(requestsToAdd));
      }

      // process all the attaches
      if (requestsByAction.get('attach') != null) {
          List<Github_Request__c> requestsToAttach = requestsByAction.get('attach');
          requestsByAction.put('attach', GithubToAgileAccelerator.attachWorkToRecords(requestsToAttach));
      }

      // process all the comments
      //removing the unlinked ones first
      //based on the existing adds and detaches
      if (requestsByAction.get('comment') != null) {
        List<Github_Request__c> requestsToComment = requestsByAction.get('comment');
        List<String> requestIds = new List<String>();

        for (Github_Request__c gr : requestsToComment ){
          requestIds.add(gr.Github_Unique_Id__c);
        }

        List<Github_Link__c> igl = new List<Github_Link__c>();
        igl = [SELECT Id, Work__c, Github_Unique_Id__c FROM Github_Link__c where Github_Unique_Id__c IN :requestIds];
        Map<String, Github_Link__c> linksByUniqueId = new Map<String, Github_Link__c>();

        for (Github_Link__c g : igl){
          linksByUniqueId.put(g.Github_Unique_Id__c, g);
        }

        List<Github_Request__c> requestsToPost = new List<Github_Request__c>();
        List<Github_Request__c> requestsToDelete = new List<Github_Request__c>();
        for (Github_Request__c gr : requestsToComment ){
          if (linksByUniqueId.containsKey(gr.Github_Unique_Id__c)){
            gr.Target__c = linksByUniqueId.get(gr.Github_Unique_Id__c).Work__c;
            requestsToPost.add(gr);
          }
          else
            requestsToDelete.add(gr);
        }

        //delete any comments from non-tracked requests
        delete requestsToDelete;

        requestsByAction.put('comment', GithubToAgileAccelerator.handleComments(requestsToPost));
      }

      // process all the detaches
      if (requestsByAction.get('detach') != null) {
          List<Github_Request__c> requestsToDetach = requestsByAction.get('detach');
          // only process detaches if 'detach' was the last command for this github record
          for (Integer i = 0; i < requestsToDetach.size(); i++) {
              if (lastAction.get(requestsToDetach[i].Github_Unique_Id__c) != 'detach') {
                  requestsToDetach.remove(i);
              }
          }
          requestsByAction.put('detach', GithubToAgileAccelerator.detachFromAllRecords(requestsToDetach));
      }

      //handle posting back to github for lurch actions requiring confirmation
      for (String requestAction : requestsByAction.keySet()) {

        if (requestAction == 'add' || requestAction == 'attach' || requestAction == 'detach'){
          //requests by action contains the updated lists thanks to the puts above
          List<Github_Request__c> ghr = requestsByAction.get(requestAction);
          String body_text = 'Tracking ';
          if (requestAction == 'detach'){ body_text = 'Detached '; }

          for (Github_Request__c greq : ghr){
            //only write back the successfully processed results
            if(greq.Status__c == 'Processed'){

              Github_Repositories__c gr = Github_Repositories__c.getValues(greq.Github_Repository__c);

              Github.Comment comment = new Github.Comment();
              comment.body = body_text + greq.Work_Link__c;
              comment.id = Integer.valueOf(greq.Github_Record_Number__c);

              //we should have a call-back mechanism to ensure non-sent post-backs are picked
              //the next time throught the scheduler... you know, for v2.
              Boolean callStackLimitExceeded = Limits.getFutureCalls() >= Limits.getLimitFutureCalls();
              if (!callStackLimitExceeded) {
                //call the @future version of the callout
                GithubRequestHandler.createGithubComment(JSON.serialize(comment), gr.Token__c, greq.Github_Repository__c);
              }
            }
          }
        }
      }
  }//close processRequests


  /*******************************************************************************************************
  * @description Async static method for calling the Github core class and posting a confirmation comment back to Github
  * @param serializedComment serialized comment to be posted to Github
  * @param github_token authentication token for Github API - generally retrieved from the custom setting earlier
  * @param repository the repository to post the comment back to
  ********************************************************************************************************/
  @future(callout=true)
  static void createGithubComment(String serializedComment, String github_token, String repository) {
      Github gh = new Github(repository, github_token);
      if (!Test.isRunningTest())
        gh.issues.createComment((Github.Comment)JSON.deserialize(serializedComment, Github.Comment.class));
  }
}