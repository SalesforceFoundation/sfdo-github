@isTest
private class GithubToAgileAccelerator_Test {

    @TestSetup static void setupTestData() {
        System.assertNotEquals(null, GithubWebhookHandler_Mock.repoSettings);
        System.assertNotEquals(null, GithubWebhookHandler_Mock.authorizedUsers);
    }

	@isTest static void testAddWorkAuthorized() {
        User testUser = AppTestUtil.get().getCommunityUser();
        System.runAs(testUser) {
            Test.startTest();

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();

            request.requestURI = '/services/apexrest/github/WebhookEvent';
            request.httpMethod = 'POST';
            request.requestBody = Blob.valueOf(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch:add'));

            RestContext.request = request;
            RestContext.response = response;

            GithubWebhookHandler.ResponseWrapper responseWrapper = GithubWebhookHandler.receiveEvent();

            Test.stopTest();

        }

        List<Github_Request__c> requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('New', requests[0].Status__c);

        (new GithubRequestHandler()).processRequests();

        requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('Processed', requests[0].Status__c);

        List<agf__ADM_Work__c> workRecords = [ SELECT Id, agf__Product_Tag__c, agf__Scrum_Team__c, agf__Subject__c, agf__Details__c FROM agf__ADM_Work__c WHERE agf__Status__c = 'New - From Github'];
        System.assertEquals(1, workRecords.size(), 'One work record should have been created.');

        System.assertEquals(AATestData.productTag.Id, workRecords[0].agf__Product_Tag__c);
        System.assertEquals(AATestData.scrumTeam.Id, workRecords[0].agf__Scrum_Team__c);
        System.assertEquals('Spelling error in the README file', workRecords[0].agf__Subject__c);
        System.assertEquals('It looks like you accidently spelled \'commit\' with two \'t\'s.', workRecords[0].agf__Details__c);

        List<GitHub_Link__c> links = [ SELECT Id, Github_Unique_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE Work__c = :workRecords[0].Id];
        System.assertEquals(1, links.size());
        System.assertEquals('Issue', links[0].GitHub_Type__c);
        System.assertEquals(requests[0].Github_Unique_Id__c, links[0].Github_Unique_Id__c);

	}

    @isTest static void testAddWorkUnauthorized() {
        // remove authorized users list
        delete [ SELECT Id FROM Github_Integration_Users__c ];

        Test.startTest();

        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();

        request.requestURI = '/services/apexrest/github/WebhookEvent';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch:add Do some stuff'));

        RestContext.request = request;
        RestContext.response = response;

        GithubWebhookHandler.ResponseWrapper responseWrapper = GithubWebhookHandler.receiveEvent();

        Test.stopTest();

        // user is not authorized; no work record should be created
        List<Github_Request__c> requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('Rejected', requests[0].Status__c);
    }

    @isTest static void testAttachToWorkAuthorized() {
        agf__ADM_Work__c work = AATestData.work;
        work = [SELECT Name FROM agf__ADM_Work__c WHERE Id = :work.Id];

        User testUser = AppTestUtil.get().getCommunityUser();

        System.runAs(testUser) {
            Test.startTest();

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();

            request.requestURI = '/services/apexrest/github/WebhookEvent';
            request.httpMethod = 'POST';
            request.requestBody = Blob.valueOf(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch:attach ' + work.Name));

            RestContext.request = request;
            RestContext.response = response;

            GithubWebhookHandler.ResponseWrapper responseWrapper = GithubWebhookHandler.receiveEvent();

            Test.stopTest();
        }

        List<Github_Request__c> requests = [ SELECT Id, Github_Unique_Id__c, Status__c, Target__c, Action__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('New', requests[0].Status__c);
        System.assertEquals(work.Name, requests[0].Target__c);
        System.assertEquals('attach', requests[0].Action__c);

        (new GithubRequestHandler()).processRequests();

        requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('Processed', requests[0].Status__c);

        List<GitHub_Link__c> links = [ SELECT Id, Github_Unique_Id__c, GitHub_Type__c, Work__c FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(1, links.size());
        System.assertEquals('Issue', links[0].GitHub_Type__c);
        System.assertEquals(requests[0].Github_Unique_Id__c, links[0].Github_Unique_Id__c);
    }

    @isTest static void testAttachToWorkNoMatchingWork() {
        agf__ADM_Work__c work = AATestData.work;

        User testUser = AppTestUtil.get().getCommunityUser();

        System.runAs(testUser) {
            Test.startTest();

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();

            request.requestURI = '/services/apexrest/github/WebhookEvent';
            request.httpMethod = 'POST';
            request.requestBody = Blob.valueOf(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch:attach W-000000'));

            RestContext.request = request;
            RestContext.response = response;

            GithubWebhookHandler.ResponseWrapper responseWrapper = GithubWebhookHandler.receiveEvent();

            Test.stopTest();
        }

        List<Github_Request__c> requests = [ SELECT Id, Github_Unique_Id__c, Status__c, Target__c, Action__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('New', requests[0].Status__c);
        System.assertEquals('W-000000', requests[0].Target__c);
        System.assertEquals('attach', requests[0].Action__c);

        (new GithubRequestHandler()).processRequests();

        requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('Rejected', requests[0].Status__c);

        List<GitHub_Link__c> links = [ SELECT Id FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(0, links.size());
    }

    @isTest static void testAttachToWorkAlreadyLinked() {
        // create work
        agf__ADM_Work__c work = AATestData.work;
        System.assertNotEquals(null, work.Name);

        // create a link to that work before we call attach
        GitHub_Link__c link = new GitHub_Link__c(
            GitHub_Unique_Id__c = 'public-repo_Issue_73464126',
            GitHub_Type__c = 'Issue',
            Work__c = work.Id
        );

        insert link;

        User testUser = AppTestUtil.get().getCommunityUser();

        System.runAs(testUser) {

            Test.startTest();

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();

            request.requestURI = '/services/apexrest/github/WebhookEvent';
            request.httpMethod = 'POST';
            request.requestBody = Blob.valueOf(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch:attach ' + work.Name));

            RestContext.request = request;
            RestContext.response = response;

            GithubWebhookHandler.ResponseWrapper responseWrapper = GithubWebhookHandler.receiveEvent();

            Test.stopTest();
        }

        List<Github_Request__c> requests = [ SELECT Id, Github_Unique_Id__c, Status__c, Target__c, Action__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('New', requests[0].Status__c);
        System.assertEquals(work.Name, requests[0].Target__c);
        System.assertEquals('attach', requests[0].Action__c);

        (new GithubRequestHandler()).processRequests();

        requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('Rejected', requests[0].Status__c);

        List<GitHub_Link__c> links = [ SELECT Id FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(1, links.size());
    }

    @isTest static void testDetachFromWork() {
        // create work
        agf__ADM_Work__c work = AATestData.work;
        System.assertNotEquals(null, work.Name);

        // create a link to that work before we call attach
        GitHub_Link__c link = new GitHub_Link__c(
            GitHub_Unique_Id__c = 'public-repo_Issue_73464126',
            GitHub_Type__c = 'Issue',
            Work__c = work.Id
        );

        insert link;

        List<GitHub_Link__c> links = [ SELECT Id FROM GitHub_Link__c WHERE Work__c = :work.Id];
        System.assertEquals(1, links.size());

        User testUser = AppTestUtil.get().getCommunityUser();

        System.runAs(testUser) {
            Test.startTest();

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();

            request.requestURI = '/services/apexrest/github/WebhookEvent';
            request.httpMethod = 'POST';
            request.requestBody = Blob.valueOf(GithubWebhookHandler_Mock.mockIssueCommentEvent('**lurch:remove'));

            RestContext.request = request;
            RestContext.response = response;

            GithubWebhookHandler.ResponseWrapper responseWrapper = GithubWebhookHandler.receiveEvent();

            Test.stopTest();
        }

        List<Github_Request__c> requests = [ SELECT Id, Github_Unique_Id__c, Status__c, Target__c, Action__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('New', requests[0].Status__c);
        System.assertEquals('remove', requests[0].Action__c);

        (new GithubRequestHandler()).processRequests();

        requests = [ SELECT Id, Github_Unique_Id__c, Status__c FROM Github_Request__c];
        System.assertEquals(1, requests.size());
        System.assertEquals('Processed', requests[0].Status__c);

        links = [ SELECT Id FROM GitHub_Link__c];
        System.assertEquals(0, links.size());
    }

}
