Package.describe({
	summary: "Custom client and server libs and tools"
});

Package.on_use(function (api, where) {
	//if(api.export) { api.export('liquidForm'); }

	api.use(['jquery', 'underscore', 'moment', 'coffeescript',  'underscore-string-latest', 'meteor', 'templating', 'ejson', 'deps', 'less', 'font-awesome-4-less', 'tools'], 'client');
	api.add_files('lib/variables.less', 'client');
	api.add_files('lib/style.less', 'client');
	api.add_files('lib/liquid-form.coffee', 'client');
});
