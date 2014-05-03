Meteor.liquidForm = (selector, config) -> new LiquidForm selector, config
class LiquidForm
	constructor: (@selector, @configMap) ->
		@items = {}
		#logmr 'lf.init: container',
		@container = $(selector).addClass 'liquid-form'
		@container.data 'lf', @
		@options = @configMap.options ? {}
		delete @configMap.options
		# TODO set default options

		@parse()

	parse: -> @initItem selector, config for selector, config of @configMap
	initItem: (selector, config) ->
		#logmr 'lf.init: item',
		element = $ selector, @container
		if element.length > 0 then @items[selector] = new LiquidFormItem element, config, @options, @container
		else log "LiquidForm: item '#{selector}' not found."

	getItem: (selector) -> @items[selector]
	closePicker: -> (logr item).hidePicker() for own s, item of logmr 'LiquidForm.closePicker: all items:', @items

class LiquidFormItem
	constructor: (@container, @config, @options, @form) ->
		@ensureHtml()
		if _.isFunction @config then @config = onChange: @config
		@container.data 'lf-item', @
		@hidePicker()
		@hookUpHandlers()

	ensureHtml: ->
		@container.addClass 'lf-item'
		if (@picker = $ '.lf-picker', @container).length < 1
			@picker = @container.children().first().addClass 'lf-picker'
		@picker.css 'min-width', @picker.width()
		@picker.css 'min-height', @picker.height()
		@label = $ '<span class="lf-label">label</span>'
			.insertBefore @picker
		@prefix = $ '<span class="lf-prefix">prefix</span>'
			.insertBefore @label
		@suffix = $ '<span class="lf-suffix">suffix</span>'
			.insertAfter @label
		@close = $ '<a class="lf-close"><i></i></a>'
			.appendTo @picker

	hookUpHandlers: ->
		@label.click => @showPicker()
		@close.click => @hidePicker()
		($ document).click (e) => @maybeHide e

	showPicker: ->
		later => # showPicker does not return false to not stop the click so that other fl-items get hidden but this will also tricker this maybeHide method; but later will trigger only after the maybeHide
			logmr 'lf.showPicker', @picker.addClass 'lf-modal'
				.addClass @getModeClass()
				.show()

	isHidden: -> @picker.is(':hidden')
	maybeHide: (e) -> unless @isHidden()
		o = @picker.offset(); x = e.pageX; y = e.pageY
		w = @picker.outerWidth(); h = @picker.outerHeight()
		log "lf.maybeHide: left=#{o.left}; top=#{o.top}; width=#{w}; height=#{h}; x=#{x}; y=#{y}"
		@hidePicker() unless x? and y? and o.left <= x <= o.left+w and o.top <= y <= o.top+h
	hidePicker: -> unless @isHidden()
		log 'lf.hidePicker..,'
		@picker.hide().removeClass 'lf-modal'
		if @options.data? then logmr 'lf.hidePicker: updated from form', u.updateFromForm @form, @options.data
		@updateLabels logmr 'lf.hidePicker: parsed labels',  @parseLabels @config.onChange()

	parseLabels: (labels) ->
		if _.isArray(l = labels) then valid: true, prefix: l[0], label: l[1], suffix: l[2], value: l[1]
		else if _.isString l then valid: true, label: l
		else valid: false

	_setOrHide: (e,c) -> if isEmpty c then e.hide() else e.show().html c
	updateLabels: (labels) ->
		if labels.valid
			@label.html labels.label
			@_setOrHide @prefix, labels.prefix
			@_setOrHide @suffix, labels.suffix
		else @label.html logmr 'mapWidget.updateLabels: invalid labels', labels

	getModeClass: -> if @isFullscreen() then 'lf-fullscreen' else 'lf-relative'
	isFullscreen: ->
		if (f = @options.fullscreen)? then f
		else @picker.width()*2 > (d = $ document).innerWidth() or @picker.height()*2 > d.innerHeight()
