@isTest
private class GithubToAgileAccelerator_Test {

    @TestSetup static void setupTestData() {
        System.assertNotEquals(null, GithubIssueCommentHandler_Mock.repoSettings);
        System.assertNotEquals(null, GithubIssueCommentHandler_Mock.authorizedUsers);
    }
	
	@isTest static void testAddWorkAuthorized() {
        User testUser = AppTestUtil.get().getCommunityUser();
        System.runAs(testUser) {
            Test.startTest();

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();

            request.requestURI = '/services/apexrest/github/issueCommentEvent';
            request.httpMethod = 'POST';
            request.requestBody = Blob.valueOf(GithubIssueCommentHandler_Mock.mockIssueCommentEvent('**lurch:add'));

            RestContext.request = request;
            RestContext.response = response;
                
            GithubIssueCommentHandler.ResponseWrapper responseWrapper = GithubIssueCommentHandler.receiveEvent();
            
            Test.stopTest(); 

            List<agf__ADM_Work__c> workRecords = [ SELECT Id, agf__Product_Tag__c, agf__Scrum_Team__c, agf__Subject__c, agf__Details__c FROM agf__ADM_Work__c WHERE agf__Status__c = 'New - From Github'];
            System.assertEquals(1, workRecords.size(), 'One work record should have been created.');

            System.assertEquals(AATestData.productTag.Id, workRecords[0].agf__Product_Tag__c);
            System.assertEquals(AATestData.scrumTeam.Id, workRecords[0].agf__Scrum_Team__c);
            System.assertEquals('Spelling error in the README file', workRecords[0].agf__Subject__c);
            System.assertEquals('It looks like you accidently spelled \'commit\' with two \'t\'s.', workRecords[0].agf__Details__c);
            
            List<GitHub_Link__c> links = [ SELECT Id, GitHub_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE Work__c = :workRecords[0].Id];
            System.assertEquals(1, links.size());
            System.assertEquals('Issue', links[0].GitHub_Type__c);
            System.assertEquals('73464126', links[0].GitHub_Id__c);
        }
	}
/*
    @isTest static void testAddWorkUnauthorized() {
        // remove authorized users list
        delete [ SELECT Id FROM Github_Integration_Users__c ];

        Test.startTest();

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/services/apexrest/github/issueCommentEvent';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(GithubIssueCommentHandler_Mock.mockIssueCommentEvent('**lurch:add Do some stuff'));

        RestContext.request = request;
        RestContext.response = response;
            
        GithubIssueCommentHandler.ResponseWrapper responseWrapper = GithubIssueCommentHandler.receiveEvent();
        
        Test.stopTest(); 

        // user is not authorized; no work record should be created
        List<agf__ADM_Work__c> workRecords = [ SELECT Id FROM agf__ADM_Work__c WHERE agf__Status__c = 'New - From Github'];
        System.assertEquals(0, workRecords.size(), 'No work records should have been created.');
    }

    @isTest static void testAttachToWorkAuthorized() {
        agf__ADM_Work__c work = AATestData.work;

        Test.startTest();

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/services/apexrest/github/issueCommentEvent';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(GithubIssueCommentHandler_Mock.mockIssueCommentEvent('**lurch:attach ' + work.Name));

        RestContext.request = request;
        RestContext.response = response;
            
        GithubIssueCommentHandler.ResponseWrapper responseWrapper = GithubIssueCommentHandler.receiveEvent();
        
        Test.stopTest(); 

        System.assertEquals(work.Id, responseWrapper.recordId);

        List<GitHub_Link__c> links = [ SELECT Id, GitHub_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(1, links.size());
        System.assertEquals('Issue', links[0].GitHub_Type__c);
        System.assertEquals('73464126', links[0].GitHub_Id__c);
    }

    @isTest static void testAttachToWorkNoMatchingWork() {
        agf__ADM_Work__c work = AATestData.work;

        Test.startTest();

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/services/apexrest/github/issueCommentEvent';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(GithubIssueCommentHandler_Mock.mockIssueCommentEvent('**lurch:attach W-000000'));

        RestContext.request = request;
        RestContext.response = response;
            
        GithubIssueCommentHandler.ResponseWrapper responseWrapper = GithubIssueCommentHandler.receiveEvent();
        
        Test.stopTest(); 

        System.assertEquals(null, responseWrapper.recordId);

        List<GitHub_Link__c> links = [ SELECT Id, GitHub_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(0, links.size());
    }

    @isTest static void testAttachToWorkAlreadyLinked() {
        // create work
        agf__ADM_Work__c work = AATestData.work;
        System.assertNotEquals(null, work.Name);

        // create a link to that work before we call attach
        GitHub_Link__c link = new GitHub_Link__c(
            GitHub_Id__c = '73464126', 
            GitHub_Type__c = 'Issue',
            Work__c = work.Id
        );

        insert link;

        Test.startTest();

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/services/apexrest/github/issueCommentEvent';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(GithubIssueCommentHandler_Mock.mockIssueCommentEvent('**lurch:attach ' + work.Name));

        RestContext.request = request;
        RestContext.response = response;
            
        GithubIssueCommentHandler.ResponseWrapper responseWrapper = GithubIssueCommentHandler.receiveEvent();
        
        Test.stopTest(); 

        System.assertEquals(work.Id, responseWrapper.recordId);

        List<GitHub_Link__c> links = [ SELECT Id, GitHub_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(1, links.size());
    }

    @isTest static void testDetachFromWork() {
        // create work
        agf__ADM_Work__c work = AATestData.work;
        System.assertNotEquals(null, work.Name);

        // create a link to that work before we call attach
        GitHub_Link__c link = new GitHub_Link__c(
            GitHub_Id__c = '73464126', 
            GitHub_Type__c = 'Issue',
            Work__c = work.Id
        );

        insert link;

        //agf__ADM_Work__c work2 = new agf__ADM_Work__c (
        //    agf__Details__c = 'Details, details.',
        //    agf__Product_Tag__c = AATestData.productTag.Id,
        //    agf__Status__c = 'New',
        //    agf__Subject__c = 'Do something else entirely'
        //);
        //insert work2;

        //GitHub_Link__c link2 = new GitHub_Link__c(
        //    GitHub_Id__c = '73464126', 
        //    GitHub_Type__c = 'Issue',
        //    Work__c = work2.Id
        //);

        //insert link2;

        List<GitHub_Link__c> links = [ SELECT Id, GitHub_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE GitHub_Id__c = '73464126'];
        System.assertEquals(1, links.size());

        Test.startTest();

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/services/apexrest/github/issueCommentEvent';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(GithubIssueCommentHandler_Mock.mockIssueCommentEvent('**lurch:remove'));

        RestContext.request = request;
        RestContext.response = response;
            
        GithubIssueCommentHandler.ResponseWrapper responseWrapper = GithubIssueCommentHandler.receiveEvent();
        
        Test.stopTest(); 

        System.assertEquals(null, responseWrapper.recordId);

        links = [ SELECT Id, GitHub_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE GitHub_Id__c = '73464126'];
        System.assertEquals(0, links.size());
    }
*/
}