Meteor.liquidForm = (selector, config) -> new LiquidForm selector, config

class LiquidForm
  constructor: (@selector, @configMap = {}) ->
    @items = {}
    #logmr 'lf.init: container',
    @container = $(selector).addClass 'liquid-form'
    @container.data 'lf', @
    @options = @configMap.options ? {}
    delete @configMap.options

    # set default options
    @options.fadeIn ?= 250
    @options.fadeOut ?= 250

    @initItems()
    @initFoldables()

  initItems: -> @initItem selector, config for selector, config of @configMap
  initItem: (selector, config) ->
    #logmr 'lf.init: item',
    element = $ selector, @container
    if element.length > 0 then @items[selector] = new LiquidFormItem element, config, @options, @container
    else log "LiquidForm: item '#{selector}' not found!"

  initFoldables: ->
    new LiquidFormFoldable $ foldable for foldable in $ '.lf-foldable', (if @options.localFoldables then @container)
    @initToggle $ toggle for toggle in $ '.lf-toggle', (if @options.localToggles then @container)
  initToggle: (node) ->
    data = node.data()
    label = if (isItem = node.is '.lf-item') then node.find '.lf-label' else node
    raw = node.is '.lf-raw'
    unless isItem or raw
      text = (data.text ? 'Open|Close').split '|'
      node.addClass 'lf-label'
    unless (foldable = (target = $ data.target).data?()?.lfFoldable ? new LiquidFormFoldable target)?
      return loge "LiquidForm: foldable '#{target}' not found. You need to add data-target=\"... CSS path to find the foldable \" to your toggle tag.", node
    updateLabel = (closed) ->
      node.text text[if closed then 0 else 1] unless raw or isItem
      node.toggleClass 'lf-closed', closed
      node.toggleClass 'lf-open', not closed
    if not raw then Deps.autorun -> updateLabel foldable.closed()
    node.on 'click', -> logmr '#####', node, foldable.toggle()
    Deps.nonreactive -> updateLabel foldable.closed()

  getItem: (selector) -> @items[selector]
  allItems: -> (item for own s, item of logmr 'LiquidForm.closePicker: all items:', @items)
  closePicker: -> (logr item).hidePicker() for item in @allItems()
  update: -> item.update() for item in @allItems()


class LiquidFormFoldable
  constructor: (@container) ->
    logmr 'new lfFoldable...', @container.addClass('lf-foldable').data 'lfFoldable', @
    unless @container? and @container.length > 0
      return loge "LiquidForm: foldable not found", @container
    @dep = new Deps.Dependency
    if @container.is '.lf-touch-fullscreen'
      @closeBtn = $ '<button type="button" class="lf-close" title="Done!"><i></i></button>'
        .appendTo @container
        .click => @close true
    @close @_closed() or (data = @container.data())?.closed ? not (data?.open ? false)

  _closed: -> @container.is('.lf-closed')
  toggle: -> @close not @_closed()
  close: (closed) ->
    if closed isnt @_closed()
      @dep.changed()
      @container.toggleClass 'lf-closed', closed
      @container.toggleClass 'lf-open', not closed
  closed: -> @dep.depend(); @_closed()
  opened: -> @dep.depend(); not @_closed()


class LiquidFormItem
  constructor: (@container, @config, @options, @form) ->
    if _.isFunction configFn = @config then @config = onChange: configFn
    @config.title ?= @container.data 'title'

    @ensureHtml()
    @container.data 'lf-item', @
    @hidePicker false # initialzes picker and labels without animations
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
    #@label.click => @showPicker()
    @label.click => @togglePicker()
    @close.click => @hidePicker()
    ($ document).click (e) => @maybeHide e

  togglePicker: ->
    showPicker = @isHidden()
    #@config.onToggle? showPicker
    #@options.onToggle? showPicker
    #Meteor.liquidForm.onToggle? showPicker # HACK: use event mechanism
    #showPicker = (@options.onToggle? showPicker) ? showPicker
    # the handlers can override showing and hiding by returning a boolean
    showPicker = u.doIfMulti [@config.onToggle, @options.onToggle, Meteor.liquidForm.onToggle], [showPicker], showPicker
    if showPicker then @showPicker() else @hidePicker()

  showPicker: ->
    @fixSize()
    later => # showPicker does not return false to not stop the click so that other fl-items get hidden but this will also tricker this maybeHide method; but later will trigger only after the maybeHide
      isFullscreen = @isFullscreen()
      @config.onBeforeShow? isFullscreen
      @options.onBeforeShow? isFullscreen
      Meteor.liquidForm.onBeforeShow? isFullscreen # HACK: use event mechanism
      logmr 'lf.showPicker', @picker.addClass 'lf-modal'
        .addClass @getModeClass isFullscreen
        .show @options.fadeIn, => later => @config.onShow? isFullscreen
      @container.addClass 'lf-open'
      unless isFullscreen # fix relative position to be completely on screen and below label (=container)
        u.showBelow @picker, @container

  isHidden: -> @picker.is(':hidden')
  maybeHide: (e) -> unless @isHidden()
    o = @picker.offset(); x = e.pageX; y = e.pageY
    w = @picker.outerWidth(); h = @picker.outerHeight()
    logmr "lf.maybeHide: left=#{o.left}; top=#{o.top}; width=#{w}; height=#{h}; x=#{x}; y=#{y}, isChild", isChild = (($ e.toElement)?.parents '.lf-picker').length > 0
    @hidePicker @ unless isChild or (x? and y? and o.left <= x <= o.left+w and o.top <= y <= o.top+h)
  hidePicker: (animation = @options.fadeOut) -> unless @isHidden()
    log 'lf.hidePicker...,'
    @picker.hide animation, =>
      @picker.removeClass('lf-modal lf-fullscreen lf-relative').css('left', '').css 'top', ''
      @container.removeClass 'lf-open'
      @config.onAfterHide?()
      @options.onAfterHide?()
      Meteor.liquidForm.onAfterHide?() # HACK: use event mechanism
    if (dataObj = @options.data)?
      dataObj = dataObj() if _.isFunction dataObj
      logmr 'lf.hidePicker: updated from form', u.updateFromForm @form, dataObj
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
