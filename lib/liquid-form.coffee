Meteor.liquidForm = (selector, config) -> new LiquidForm selector, config
class LiquidForm
	constructor: (@selector, @config) ->
		@root = $ selector
		@options = @config.options ? {}
		delete @config.options
		# set default options
		
		@parse()

	parse: -> @initItem ($ key), obj for key, obj of @config
	initItem: (element, def) ->
		new LiquidFormItem (element, def, @config)

class LiquidFormItem
	constructor: (@root, @definition, @config) ->
		@ensureHtml()
		@hookUpHandlers()
	
	ensureHtml() ->
		@picker = $ '.lf-picker', @root
		# @orgWidth = @picker.width()
		@picker.css 'width', @picker.width()
		@label = $ '<span class="lf-label">label</span>'
			.insertBefore picker
		@prefix = $ '<span class="lf-prefix">prefix</span>'
			.insertBefore label
		@suffix = $ '<span class="lf-suffix">suffix</span>'
			.insertAfter label

	hookUpHandlers: ->
		@label.click @showPicker
		($ document).click @maybeHide

	showPicker: =>
		@picker.addClass 'lf-modal'
			.addClass @getModeClass()

	maybeHide: (e) =>
		o = @picker.offset(); x = e.pageX; y = e.pageY
		w = @picker.width(); h = @picker.height()
		unless o.left <= x <= o.left+w and o.top <= y <= o.top+h
			@picker.removeClass 'lf-modal'
			@updateLabels @parseLabels @definition.onChange()

	parseLabels: (labels) ->
		if _.isArray (l=labels) 
			valid:true prefix:l[0] label:l[1] suffix:l[2] value:l[1]
		else if _.isString l then valid:true label:l
		else valid:false

	_setOrHide: (e,c) -> if isEmpty c then e.hide() else e.show().html c
	updateLabels: (labels) ->
		if labels.valid 
			@label.html labels.label
			@_setOrHide @prefix, labels.prefix
			@_setOrHide @suffix, labels.suffix

	getModeClass: if @isFullscreen() then 'lf-fullscreen' else 'lf-relative'
	isFullscreen: ->
		if (f = @config.fullscreen) then f
		else @picker.width()*2 > ($ document).clientWidth()
