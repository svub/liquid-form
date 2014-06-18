Package.describe({
    summary: "Custom client and server libs and tools"
});

Package.on_use(function (api, where) {
    //if(api.export) { api.export('liquidForm'); }

    api.use(['jquery', 'underscore', 'moment', 'coffeescript',  'underscore-string-latest', 'meteor', 'templating', 'ejson', 'deps', 'less', 'font-awesome-4-less', 'tools'], 'client');
    // you'll need to import style.import.less and variables.standalone.import.less or
    // variables.using-bootstrap.import.less yourself (latter preset colors using Less vars of bootstrap
    //api.add_files('lib/variables.less', 'client');
    //api.add_files('lib/style.less', 'client');
    api.add_files('lib/liquid-form.coffee', 'client');
});
