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
* @description Handles the actual creation of Agile Accelerator records from Github hooks
*/
global without sharing class GithubToAgileAccelerator {
	//lurch.processGithubEvent = function (event_name, event_id, event_body) {
    /*only listen and forward:
    1.  anything with **lurch:add from a known user
    2.  anything with **lurch:attach w-xxxxxxxxxxxx or epic:XXXXXXX from a known user
    3.  anything with **lurch:remove from a known user
    4.  anything currently being actively tracked, regardless of user
    5.  pull requests from a known user
    (?) 5.  milestones
    */

  /*******************************************************************************************************
  * @description Static string for returning base URL
  ********************************************************************************************************/
  public static String INSTANCE_URL = URL.getSalesforceBaseURL().toExternalForm();//'https://foundation--kbromer.cs30.my.salesforce.com/';

  /*******************************************************************************************************
  * @description Returns the set of authorized Github usernames for this org
  ********************************************************************************************************/
  private static Set<String> authorizedUsers {
      get {
          if (authorizedUsers == null) {
              authorizedUsers = new Set<String>();
              List<Github_Integration_Users__c> users = Github_Integration_Users__c.getAll().values();
              for (Github_Integration_Users__c user : users) {
                  authorizedUsers.add(user.Github_Username__c);
              }
          }
          return authorizedUsers;
      }
      set;
  }

  /*******************************************************************************************************
  * @description Checks a given Github username for authorization to interact w/ the integration
  * @param githubUsername the String named of the username to check
  * @return Boolean
  ********************************************************************************************************/
  global static Boolean isAuthorizedUser(String githubUsername) {
      return authorizedUsers.contains(githubUsername);
  }

  /*******************************************************************************************************
  * @description Checks the validity of a command from Lurch/Github-AA
  * @param command the String command from the Github comment/issue post
  * @return Boolean
  ********************************************************************************************************/
  global static Boolean isRecognizedCommand(String command) {
      Set<String> recognizedCommands = new Set<String>{ 'add', 'attach', 'detach', 'comment' };
      return (recognizedCommands.contains(command));
  }

  /*******************************************************************************************************
  * @description Checks a repository name against the configured valid repositories
  * @param repositoryName the name of the repository to check
  * @return Boolean
  ********************************************************************************************************/
  global static Boolean isMappedRepository(String repositoryName) {
      return repositoryMap.keySet().contains(repositoryName);
  }

  /*******************************************************************************************************
  * @description Returns a map of the Settings name and the Github_Repositories__c object
  * @return Map<String, Github_Repositories__c>
  ********************************************************************************************************/
  private static Map<String, Github_Repositories__c> repositoryMap {
      get {
          if (repositoryMap == null) {
              repositoryMap = Github_Repositories__c.getall();
          }
          return repositoryMap;
      }
      set;
  }

  /*******************************************************************************************************
  * @description Action class - defined a given action with type, target and body
  ********************************************************************************************************/
  global class Action {
      global String type;
      global String target;
      global String body;
  }

  /*******************************************************************************************************
  * @description Parses the body of a comment/etc. and returns an Action object containing info about the request
  * @param body the String representation of the body - issue, comment, etc.
  * @return Action
  ********************************************************************************************************/
  public static Action parseAction(String body) {
      Pattern p = Pattern.compile('[\\*\\*]{2}[lL]urch:\\s*((?i)[a-z]+)( (?i)w-[0-9]+)?');
      Matcher pm = p.matcher( body );
      pm.find();
      Action act = new Action();
      act.type = pm.group(1);
      if (pm.group(2) != null) {
          act.target = pm.group(2).trim();
      }
      act.body = pm.replaceAll('').trim();

      return act;
  }

  /*******************************************************************************************************
  * @description Generate a new unique Id based on the repository and the record number
  * @param request the Github_Request__c to generate the Id from
  * @return String
  ********************************************************************************************************/
  public static String getUniqueId(Github_Request__c request) {
      return getUniqueId(request.Github_Repository__c, request.Github_Record_Number__c);
  }

  /*******************************************************************************************************
  * @description Generate a new unique Id based on the repository and the record number - supports Webhook queries
  * @param repositoryName name of the Github repo for this item
  * @param githubRecordNumber the issue or pull request number as an integer
  * @return String
  ********************************************************************************************************/
  public static String getUniqueId(String repositoryName, String githubRecordNumber) {
      return repositoryName+ '_' + githubRecordNumber;
  }

  /*******************************************************************************************************
  * @description Adds work records to AA based on the previously verified requests passed to it
  * @param gitRequests a collection of Github_Request__c that need AA work records created
  * @return List<Github_Request__c>
  ********************************************************************************************************/
  public static List<Github_Request__c> addWorkRecords(List<Github_Request__c> gitRequests) {
      // github unique Id => work
      Map<String, agf__ADM_Work__c> workToCreate = new Map<String, agf__ADM_Work__c>();

      // Id => work
      Map<Id, agf__ADM_Work__c> newWorkWithName = new Map<Id, agf__ADM_Work__c>();

      // github unique Id => request
      Map<String, Github_Request__c> requests = new Map<String, Github_Request__c>();
      List<GitHub_Link__c> linksToCreate = new List<GitHub_Link__c>();

      for (Github_Request__c gitRequest : gitRequests) {
          // create the work record
          workToCreate.put( gitRequest.Github_Unique_Id__c, new agf__ADM_Work__c (
              agf__Details__c = gitRequest.Body__c,
              agf__Perforce_Status__c = 'Attached',
              agf__Product_Tag__c = repositoryMap.get(gitRequest.Github_Repository__c).Product_Tag__c,
              agf__Status__c = 'New - From Github',
              agf__Subject__c = gitRequest.Title__c
          ));
          requests.put(gitRequest.Github_Unique_Id__c, gitRequest);
      }
      // insert work
      if (!workToCreate.values().isEmpty()) {
          insert workToCreate.values();
          // requery for created name/etc. to provide links
          newWorkWithName = new Map<Id, agf__ADM_Work__c>([select id, Name from agf__ADM_Work__c where id IN :workToCreate.values()]);
      }
      List<FeedItem> chatterComments = new List<FeedItem>();
      for (String uniqueId : workToCreate.keySet()) {
          // create link to work
          linksToCreate.add( new GitHub_Link__c(
              GitHub_Unique_Id__c = requests.get(uniqueId).Github_Unique_Id__c,
              GitHub_Type__c = requests.get(uniqueId).Github_Record_Type__c,
              Github_URL__c = requests.get(uniqueId).Github_Record_URL__c,
              Work__c = workToCreate.get(uniqueId).Id
          ));
          requests.get(uniqueId).Status__c = 'Processed';
          requests.get(uniqueId).Work_Link__c = '<a href="' + INSTANCE_URL + '/' + workToCreate.get(uniqueId).Id + '"' + ' target="_blank">' + newWorkWithName.get(workToCreate.get(uniqueId).Id).Name + '</a>';
          requests.get(uniqueId).Target__c = workToCreate.get(uniqueId).Id;

          FeedItem fi = new FeedItem(
            ParentId = workToCreate.get(uniqueId).Id,
            Type = 'TextPost',
            Body = 'Issue created by ' + requests.get(uniqueId).Github_Record_URL__c
          );
          chatterComments.add(fi);
      }

      if (!chatterComments.isEmpty()) insert chatterComments;

      // insert links
      if (!linksToCreate.isEmpty()) {
          insert linksToCreate;
      }

      // update requests with new status
      update requests.values();
      return requests.values();
  }

  /*******************************************************************************************************
  * @description Attaches comments/requests to existing work records in Agile Accelerator
  * @param gitRequests the list of Github_Request__c to be processed
  * @return List<Github_Request__c>
  ********************************************************************************************************/
  public static List<Github_Request__c> attachWorkToRecords(List<Github_Request__c> gitRequests) {
      List<GitHub_Link__c> linksToCreate = new List<GitHub_Link__c>();
      Map<String, Id> targets = new Map<String, Id>();
      Map<String, Github_Request__c> requestMap = new Map<String, Github_Request__c>();
      Map<String, GitHub_Link__c> linkMap = new Map<String, GitHub_Link__c>();

      for (Github_Request__c gitRequest : gitRequests) {
          if (gitRequest.Target__c != null) {
              requestMap.put(gitRequest.Github_Unique_Id__c, gitRequest);
              targets.put(gitRequest.Target__c, Id.valueOf(gitRequest.Target__c));
          } else {
              gitRequest.Status__c = 'Rejected - Not a valid Target';
          }
      }

      Map<Id, agf__ADM_Work__c> workById = new Map<Id, agf__ADM_Work__c>([ SELECT Id, Name FROM agf__ADM_Work__c WHERE Id in :targets.values()]);

      // look for links with matching links and work name
      for (GitHub_Link__c link : [ SELECT Id, Work__r.Name, Work__r.Id, Github_Unique_Id__c
                                      FROM GitHub_Link__c
                                      WHERE Github_Unique_Id__c in :requestMap.keySet() ]) {
          linkMap.put(link.Github_Unique_Id__c, link);
      }

      for (Github_Request__c gitRequest : gitRequests) {
          if (linkMap.get(gitRequest.Github_Unique_Id__c) != null && requestMap.get(gitRequest.Github_Unique_Id__c).Target__c == linkMap.get(gitRequest.Github_Unique_Id__c).Work__r.Id) {
              // link already exists
              gitRequest.Status__c = 'Rejected - Link Exists';
          } else if (workById.get(gitRequest.Target__c) != null) {
              // work exists but link does not - create it
              linksToCreate.add( new GitHub_Link__c(
                  GitHub_Unique_Id__c = gitRequest.Github_Unique_Id__c,
                  GitHub_Type__c = gitRequest.Github_Record_Type__c,
                  Github_URL__c = gitRequest.Github_Record_URL__c,
                  Work__c = gitRequest.Target__c
              ));
              gitRequest.Status__c = 'Processed';
              gitRequest.Work_Link__c = '<a href="' +  INSTANCE_URL + '/' + gitRequest.Target__c + '"' + ' target="_blank">' + workById.get(gitRequest.Target__c).Name + '</a>';
          } else {
              // work not found
              gitRequest.Status__c = 'Rejected - Work Not Found';
          }
      }

      if (!linksToCreate.isEmpty()) {
          insert linksToCreate;
      }
      List<FeedItem> chatterComments = new List<FeedItem>();
      for (Github_Link__c gl : linksToCreate){
        FeedItem fi = new FeedItem(
          ParentId = gl.Work__c,
          Type = 'TextPost',
          Body = gl.Github_URL__c + ' has been attached to this work item'
        );
        chatterComments.add(fi);
      }
      if (!chatterComments.isEmpty()) insert chatterComments;

      update gitRequests;
      return gitRequests;
  }

  /*******************************************************************************************************
  * @description Detaches a Github issue from its Agile Accelerator work record
  * @param gitRequests a List of Github_Request__c objects
  * @return List<Github_Request__c>
  ********************************************************************************************************/
  public static List<Github_Request__c> detachFromAllRecords(List<Github_Request__c> gitRequests){
      List<String> githubUniqueIds = new List<String>();
      List<FeedItem> chatterComments = new List<FeedItem>();
      for (Github_Request__c gitRequest : gitRequests) {
          githubUniqueIds.add(gitRequest.Github_Unique_Id__c);
      }

      List<GitHub_Link__c> linksToDelete =
          [ SELECT Id, Github_Unique_Id__c, Work__c, Work__r.Name, Github_URL__c FROM GitHub_Link__c WHERE Github_Unique_Id__c in :githubUniqueIds];

      for (Github_Link__c g : linksToDelete){
        FeedItem fi = new FeedItem(
          ParentId = g.Work__c,
          Type = 'TextPost',
          Body = g.Github_URL__c + ' has been detached from this work item'
        );
        chatterComments.add(fi);
      }

      for (Github_Request__c gitRequest : gitRequests) {
        gitRequest.Status__c = 'Processed';
        for (Github_Link__c g : linksToDelete){
          if (g.Github_Unique_Id__c == gitRequest.Github_Unique_Id__c)
            gitRequest.Work_Link__c = '<a href="' +  INSTANCE_URL + '/' + g.Work__c + '"' + ' target="_blank">' + g.Work__r.Name + '</a>';
        }
      }

      if (!linksToDelete.isEmpty()) {
        delete linksToDelete;
      }
      if (!chatterComments.isEmpty()){
        insert chatterComments;
      }

      update gitRequests;
      return gitRequests;
  }

  /*******************************************************************************************************
  * @description Inserts Chatter comments for Github requests that are already linked to existing Agile Accelerator work records
  * @param gitRequests a List of Github_Request__c objects that needs Chatter comments created
  * @return List<Github_Request__c>
  ********************************************************************************************************/
  public static List<Github_Request__c> handleComments(List<Github_Request__c> gitRequests){

    List<FeedItem> fis = new List<FeedItem>();
    for (Github_Request__c gr : gitRequests){
      if (gr.Action__c == 'comment'){
        String posttext = '@' + gr.Github_Username__c + ': ' + gr.Body__c;
        FeedItem fi = new FeedItem(
          ParentId = gr.Target__c,
          Type = 'TextPost',
          Body = posttext
        );
        gr.Status__c = 'Processed';
        fis.add(fi);
      }
    }
    if (!fis.isEmpty())
      insert fis;

    update gitRequests;
    return gitRequests;
  }
}
