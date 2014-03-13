Package.describe({
  summary: "Custom client and server libs and tools"
});

Package.on_use(function (api, where) {
  if(api.export) { api.export('liquid-form'); }
  
  api.use(['jquery', 'underscore', 'moment', 'coffeescript',  'underscore-string-latest', 'meteor', 'ejson', 'deps'], 'client');
  api.add_files('lib/liquid-form.coffee', 'client');
  api.add_files('lib/liquid-form.less', 'client'); 
});
