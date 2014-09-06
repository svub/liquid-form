Meteor.liquidForm = (selector, config) -> new LiquidForm selector, config
class LiquidForm
  constructor: (@selector, @configMap = {}) ->
    @items = {}
    #logmr 'lf.init: container',
    @container = $(selector).addClass 'liquid-form'
    @container.data 'lf', @
    @options = @configMap.options ? {}
    delete @configMap.options
    # TODO set default options

    @initItems()
    @initFoldables()

  initItems: -> @initItem selector, config for selector, config of @configMap
  initItem: (selector, config) ->
    #logmr 'lf.init: item',
    element = $ selector, @container
    if element.length > 0 then @items[selector] = new LiquidFormItem element, config, @options, @container
    else log "LiquidForm: item '#{selector}' not found!"

  initFoldables: ->
    @initFoldable $ toggle for toggle in ($ '.lf-toggle', @container)
  initFoldable: (node) ->
    data = node.data()
    closed = data.closed ? not (data.open ? false)
    text = (data.text ? 'Open|Close').split '|'
    node.addClass 'lf-label'
    target = $ '#'+node.data().target
    target.addClass 'lf-foldable'
    updateState = (toggle = true) ->
      if toggle then closed = not closed
      target.toggleClass 'lf-closed', closed
      node.text text[if closed then 0 else 1]
      node.toggleClass 'lf-closed', closed
    node.on 'click', -> updateState()
    updateState false

  getItem: (selector) -> @items[selector]
  allItems: -> (item for own s, item of logmr 'LiquidForm.closePicker: all items:', @items)
  closePicker: -> (logr item).hidePicker() for item in @allItems()
  update: -> item.update() for item in @allItems()

class LiquidFormItem
  constructor: (@container, @config, @options, @form) ->
    if _.isFunction configFn = @config then @config = onChange: configFn
    @config.title ?= @container.data 'title'

    @ensureHtml()
    @container.data 'lf-item', @
    @hidePicker() # initialzes picker and labels
    @hookUpHandlers()

  ensureHtml: ->
    @container.addClass 'lf-item'
    if (@picker = $ '.lf-picker', @container).length < 1
      if (@picker = @container.children().first()).length < 1
        @container.append @picker = $ '<div class="lf-picker-dummy"/>'
      @picker.addClass 'lf-picker'
    #@label = $ "<span class=\"lf-label\" title=\"#{@config.title ? ''}\">label</span>"
    @label = $ '<span class="lf-label">label</span>'
      .attr 'title', @config.title
      .insertBefore @picker
    @prefix = $ '<span class="lf-prefix">prefix</span>'
      .insertBefore @label
    @suffix = $ '<span class="lf-suffix">suffix</span>'
      .insertAfter @label
    @close = $ '<button type="button" class="lf-close" title="Done!"><i></i></button>'
      .appendTo @picker

  fixSize: _.once ->
    @picker.css 'min-width', @picker.width()
    @picker.css 'min-height', @picker.height()

  hookUpHandlers: ->
    @label.click => @showPicker()
    @close.click => @hidePicker()
    ($ document).click (e) => @maybeHide e

  showPicker: ->
    @fixSize()
    later => # showPicker does not return false to not stop the click so that other fl-items get hidden but this will also tricker this maybeHide method; but later will trigger only after the maybeHide
      isFullscreen = @isFullscreen()
      logmr 'lf.showPicker', @picker.addClass 'lf-modal'
        .addClass @getModeClass isFullscreen
        .show()
      unless isFullscreen # fix relative position to be completely on screen and below label (=container)
        #d = $ document; co = @container.offset(); x = co.left; y = co.top+@container.height(); w = @picker.outerWidth(); h = @picker.outerHeight()
        #if (overflow = x+w-d.innerWidth()) > 0 then x -= overflow
        #if (overflow = x) < 0 then x -= overflow
        #if x < 0 then x = 0
        #if (overflow = y+h-d.innerHeight()) > 0 then y -= overflow
        #if (overflow = y) < 0 then y -= overflow
        #if y < 0 then y = 0
        #@picker.css 'left', x-co.left
        #@picker.css 'top', y-co.top
        #c = @container; co = c.offset()
        #u.keepCompletelyVisible @picker, co.left, co.top+@c.height(), c
        #u.keepCompletelyVisible @picker, 0, co.top+c.height(), c
        u.showBelow @picker, @container
      later =>
        @config.onShow?()

  isHidden: -> @picker.is(':hidden')
  maybeHide: (e) -> unless @isHidden()
    o = @picker.offset(); x = e.pageX; y = e.pageY
    w = @picker.outerWidth(); h = @picker.outerHeight()
    log "lf.maybeHide: left=#{o.left}; top=#{o.top}; width=#{w}; height=#{h}; x=#{x}; y=#{y}"
    @hidePicker() unless x? and y? and o.left <= x <= o.left+w and o.top <= y <= o.top+h
  hidePicker: -> unless @isHidden()
    log 'lf.hidePicker..,'
    @picker.hide().removeClass('lf-modal lf-fullscreen lf-relative').css('left', '').css 'top', ''
    if @options.data? then logmr 'lf.hidePicker: updated from form', u.updateFromForm @form, @options.data
    @update()

  update: -> @updateLabels logmr 'lf.update: parsed labels', @parseLabels @config.onChange()

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

  getModeClass: (isFullscreen = @isFullscreen()) -> if isFullscreen then 'lf-fullscreen' else 'lf-relative'
  isFullscreen: ->
    if (f = @options.fullscreen)? then f
    else Modernizr?.touch or (@picker.width()*1.5 > (d = $ document).innerWidth()) or (@picker.height()*1.5 > d.innerHeight())
