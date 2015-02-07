/* jshint node:true */
'use strict';
module.exports = function(grunt) {

  var credentials;

  try {
    var secret = grunt.file.readJSON('secret.json');
    credentials = secret.dev;
  } catch(e) {
    // No secret.json found, use env vars
    if (process.env.username &&
      process.env.password &&
      process.env.server) {

        credentials = {
          username: process.env.username,
          password: process.env.password,
          server: process.env.server
        };
      }
    }

    // project configuration.
    grunt.initConfig({
      credentials: credentials,

      /* Ant deploy tasks */
      antdeploy: {
        options: {
          apiVersion: '32.0',
          root: 'src/',
          maxPoll: 200,
          pollWaitMillis: 10000,
          existingPackage: true,
          user: '<%= credentials.username %>',
          pass: '<%= credentials.password %>',
          serverurl: '<%= credentials.server %>'
        },
        all:  {
        }
      }
    });

    grunt.loadNpmTasks('grunt-ant-sfdc');

    grunt.registerTask('default', ['antdeploy:all']);
  };
