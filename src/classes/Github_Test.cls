@isTest
private class Github_Test {

    @isTest
    static void test_setup_github() {
        Github git = new Github('repo', 'fooToken');

        System.assertNotEquals(git.milestones, null);
        System.assertEquals(git.milestones.endpoint, 'milestones');
        System.assertNotEquals(git.issues, null);
        System.assertEquals(git.issues.endpoint, 'issues');

        System.assertEquals(git.organization, 'SalesforceFoundation');
        System.assertEquals(git.repository, 'repo');

        git = new Github('otherOrg', 'repo2', 'fooToken');
        System.assertEquals(git.organization, 'otherOrg');
        System.assertEquals(git.repository, 'repo2');
    }
    
    @isTest
    static void test_milestones_get_all() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        List<Github.Milestone> milestones = git.milestones.get();
    }

    @isTest
    static void test_milestones_get_all_paginate() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        List<Github.Milestone> milestones = git.milestones.get();

        System.assert(git.milestones.hasNext);
        git.milestones.next();
        System.assert(git.milestones.hasPrev);
        git.milestones.prev();
        System.assert(git.milestones.hasLast);
        git.milestones.last();
        System.assert(git.milestones.hasFirst);
        git.milestones.first();
    }

    @isTest
    static void test_milestones_get_one() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        Github.Milestone milestone = git.milestones.get(1);

        System.assert(!git.milestones.hasNext);
        System.assert(!git.milestones.hasPrev);
        System.assert(!git.milestones.hasLast);
        System.assert(!git.milestones.hasFirst);
    }

    @isTest
    static void test_milestones_create() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        Github.Milestone milestone = new Github.Milestone();
        milestone.url = 'https://api.github.com/repos/octocat/Hello-World/milestones/1';
        milestone.num = null;
        milestone.state = 'open';
        milestone.title = 'v0.1.0-beta1';
        milestone.description = 'We release a beta';
        milestone.open_issues = 4;
        milestone.closed_issues = 8;

        Github.Milestone newMilestone = git.milestones.create(milestone);
        system.assertEquals(2, newMilestone.num);
    }

    @isTest
    static void test_milestones_update() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        Github.Milestone milestone = git.milestones.get(1);
        milestone.title = 'Foo Update';

        Github.Milestone updated = git.milestones.put(milestone);
        System.assertEquals('Foo Update', updated.title);
    }

    @isTest
    static void test_milestones_remove() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');
        Github.Milestone milestone = git.milestones.get(1);
        git.milestones.remove(milestone);
    }

    /* Issues */
    @isTest
    static void test_issues_get_all() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        List<Github.Issue> issues = git.issues.get();
    }

    @isTest
    static void test_issues_get_all_paginate() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        List<Github.Issue> issues = git.issues.get();

        System.assert(git.issues.hasNext);
        git.issues.next();
        System.assert(git.issues.hasPrev);
        git.issues.prev();
        System.assert(git.issues.hasLast);
        git.issues.last();
        System.assert(git.issues.hasFirst);
        git.issues.first();
    }

    @isTest
    static void test_issues_get_one() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        Github.Issue milestone = git.issues.get(1);

        System.assert(!git.issues.hasNext);
        System.assert(!git.issues.hasPrev);
        System.assert(!git.issues.hasLast);
        System.assert(!git.issues.hasFirst);
    }

    @isTest
    static void test_issues_create() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        Github.Issue issue = new Github.Issue();
        issue.url = 'https://api.github.com/repos/octocat/Hello-World/issues/1';
        issue.state = 'open';
        issue.title = 'A major issue';
        issue.body = 'We release a beta';

        Github.issue newIssue = git.issues.create(issue);
        system.assertEquals(2, newIssue.num);
    }

    @isTest
    static void test_issues_update() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        Github.Issue issue = git.issues.get(1);
        issue.title = 'Foo Update';

        Github.Issue updated = git.issues.put(issue);
        System.assertEquals('Foo Update', updated.title);
    }

    @isTest
    static void test_issues_remove() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');
        Github.Issue issue = git.issues.get(1);
        git.issues.remove(issue);
    }
    
}