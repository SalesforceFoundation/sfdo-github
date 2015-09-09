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
    static void test_hook() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        List<Github.Hook> hooks = git.hooks.all();
        Github.Hook h = git.hooks.get(1);
        h = git.hooks.create(h);
        h = git.hooks.put(h);
        git.hooks.remove(h);
    }

    @isTest
    static void test_milestones_get_all() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');

        List<Github.Milestone> milestones = git.milestones.get();
        milestones = git.milestones.all();
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
        issues = git.issues.all();
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
    static void test_issues_comment() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');
        Github.Comment c = new Github.Comment();
        c.id = 123;
        c = git.issues.createComment(c);
    }

    @isTest
    static void test_issues_remove() {
        Test.setMock(HttpCalloutMock.class, new GithubMock());

        Github git = new Github('repo', 'fooToken');
        Github.Issue issue = git.issues.get(1);
        git.issues.remove(issue);
    }

    @isTest
    static void test_cover_subclass_properties() {

      Github git = new Github('repo', 'fooToken');
      Github.User u = new Github.User();
      u.id = 123;
      u.avatar_url = 'http://url.com';
      u.gravatar_id = '123';
      u.url = 'http://url.com';
      u.html_url = 'http://url.com';
      u.followers_url = 'http://url.com';
      u.following_url = 'http://url.com';
      u.gists_url = 'http://url.com';
      u.starred_url = 'http://url.com';
      u.subscriptions_url = 'http://url.com';
      u.organizations_url = 'http://url.com';
      u.repos_url = 'http://url.com';
      u.events_url = 'http://url.com';
      u.type = 'type';
      u.site_admin = true;

      Github.Milestone m = new Github.Milestone();
      m.created_at = System.now();
      m.updated_at = System.now();

      Github.PullRequest p = new Github.PullRequest();
      p.url = 'http://url.com';
      p.diff_url = 'http://url.com';
      p.patch_url = 'http://url.com';
      p.state = 'Maryland';
      p.milestone = 1;
      p.id = 1;
      p.num = 1;
      p.html_url = 'http://url.com';
      p.title = 'title';
      p.user = u;
      p.body = 'body';

      Github.Issue i = new Github.Issue();
      i.body_raw = 'body';
      i.body_html = '<html>body</html>';
      i.body_text = 'body';
      i.comments = 1;
      i.closed_at = System.now();
      i.created_at = System.now();
      i.updated_at = System.now();
      i.labels_url = 'http://url.com';
      i.comments_url = 'http://url.com';
      i.events_url = 'http://url.com';
      i.id = 1;
      i.html_url = 'http://url.com';

      Github.Comment c = new Github.Comment();
      c.url = 'http://url.com';
      c.id = 1;
      c.html_url = 'http://url.com';
      c.body = 'body';
      c.user = u;
      c.created_at = System.now();
      c.updated_at = System.now();

      Github.Repository r = new Github.Repository();
      r.id = 1;
      r.name = 'name';
      r.full_name = 'repo';
      r.html_url = 'http://url.com';
      r.description = 'description text';
      r.fork = true;

      Github.PullRequestEvent pre = new Github.PullRequestEvent();
      pre.num = 1;
      pre.action = 'Action';
      pre.pull_request = p;
      pre.repository = r;

      Github.IssuesEvent ie = new Github.IssuesEvent();
      ie.action = 'action';
      ie.issue = i;
      ie.repository = r;

      Github.IssueCommentEvent ice = new Github.IssueCommentEvent();
      ice.action = 'action';
      ice.issue = i;
      ice.comment = c;
      ice.repository = r;

      Github.Hook h = new Github.Hook();
      h.url = 'http://url.com';
      h.name = 'Name';
      h.events = new List<String>();
      h.active = true;
      h.config = new Map<String, String>();
      h.id = 1;

      i.assignee = u;
      i.assigneeUsername = 'username';
      i.milestone = m;
      i.milestoneNumber = 1;
      i.closed_by = u;
      Integer num = Github.numFromUrl('http://github.com/1/2/3/4/5');
    }
}
