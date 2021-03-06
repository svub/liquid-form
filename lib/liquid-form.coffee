Meteor.liquidForm = (selector, config) -> new LiquidForm selector, config

class LiquidForm
  constructor: (@selector, @configMap = {}) ->
    @items = {}
    @container = $(selector).addClass 'liquid-form'
    @container.data 'lf', @
    @options = @configMap.options ? {}
    delete @configMap.options

    # set default options
    @options.fadeIn ?= 250
    @options.fadeOut ?= 250

    @initItems()
    @initFoldables()
    @initModals()

  initItems: -> @initItem selector, config for own selector, config of @configMap
  initItem: (selector, config) ->
    element = $ selector, @container
    if element.length > 0 then @items[selector] = new LiquidFormItem element, config, @options, @container
    else logt "LiquidForm: item '#{selector}' not found!"

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
    node.on 'click', -> foldable.toggle()
    Deps.nonreactive -> updateLabel foldable.closed()

  initModals: ->
    new LiquidFormModal $ modal for modal in $ '.lf-modal', (if @options.localModals then @container)

  getItem: (selector) -> @items[selector]
  allItems: -> (item for own s, item of @items)
  closePicker: -> item.hidePicker() for item in @allItems()
  #update: -> item.update() for item in @allItems()
  update: -> item.update false for item in @allItems()

class OpenClosed
  constructor: (@container, addCloseButton = true) ->
    @dep = new Deps.Dependency
    data = @container.data()
    if addCloseButton
      unless (@closeButton = $ '.lf-close', @container).length > 0
        @closeButton = $ '<button type="button" class="lf-close" title="Done!"><i></i> '+(data.buttonLabel ? '')+'</button>'
          .appendTo @container
      @closeButton.click => @close true
    @close (@_closed() or data?.closed ? not (data?.open ? false)), true

  _closed: -> @container.is('.lf-closed')
  toggle: -> @close not @_closed()
  open: (open = true) -> @close not open
  close: (close = true, force = false) ->
    if force or close isnt @_closed()
      @container.toggleClass 'lf-closed', close
      @container.toggleClass 'lf-open', not close
      if close then @container.hide 'fast' else @container.show 'fast'
      @dep.changed()
  closed: -> @dep.depend(); @_closed()
  opened: -> @dep.depend(); not @_closed()

class LiquidFormFoldable extends OpenClosed
  constructor: (@container) ->
    @container.addClass('lf-foldable').data 'lfFoldable', @
    unless @container? and @container.length > 0
      return logt "LiquidForm: foldable not found", @container
    #if @container.is '.lf-touch-fullscreen'
    #  @closeBtn = $ '<button type="button" class="lf-close" title="Done!"><i></i></button>'
    #    .appendTo @container
    #    .click => @close true
    super @container, @container.is '.lf-touch-fullscreen'

  #_closed: -> @container.is('.lf-closed')
  #toggle: -> @close not @_closed()
  #close: (closed) ->
  #  if closed isnt @_closed()
  #    @dep.changed()
  #    @container.toggleClass 'lf-closed', closed
  #    @container.toggleClass 'lf-open', not closed
  #closed: -> @dep.depend(); @_closed()
  #opened: -> @dep.depend(); not @_closed()


class LiquidFormItem
  constructor: (@container, @config, @options, @form) ->
    if _.isFunction configFn = @config then @config = onChange: configFn
    @config.title ?= @container.data 'title'
    @config.titlePlacement ?= @container.data 'placement'

    @ensureHtml()
    @container.data 'lf-item', @
    @hidePicker false, false # initialzes picker and labels without animations and notification
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
      .data 'placement', @config.titlePlacement
      .insertBefore @picker
    @prefix = $ '<span class="lf-prefix">prefix</span>'
      .insertBefore @label
    @suffix = $ '<span class="lf-suffix">suffix</span>'
      .insertAfter @label
    @close = $ '<button type="button" class="lf-close" title="Done!"><i></i></button>'
      .appendTo @picker

  fixSize: _.once ->
    #@picker.css 'min-width', @picker.width()
    #@picker.css 'min-height', @picker.height()
    @picker.css 'min-width', @picker.outerWidth()
    @picker.css 'min-height', @picker.outerHeight()

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
      #logmr 'lf.showPicker', @picker.addClass 'lf-modal'
      #  .addClass @getModeClass isFullscreen
      #  .slideDown @options.fadeIn, => later => @config.onShow? isFullscreen
      #@container.addClass 'lf-open'
      #unless isFullscreen # fix relative position to be completely on screen and below label (=container)
      #  u.showBelow @picker, @container
      #  if _.isNumber delay = @options.fadeIn
      #    steps = 10
      #    for step in [1..steps]
      #      later step*delay/steps, => u.showBelow @picker, @container
      @picker.addClass 'lf-modal'
        .addClass @getModeClass isFullscreen
      @container.addClass 'lf-open'
      unless isFullscreen # fix relative position to be completely on screen and below label (=container)
        u.showBelow @picker, @container
      @picker.slideDown @options.fadeIn, => later => @config.onShow? isFullscreen

  isHidden: -> @picker.is(':hidden')
  maybeHide: (e) -> unless @isHidden()
    o = @picker.offset(); x = e.pageX; y = e.pageY
    w = @picker.outerWidth(); h = @picker.outerHeight()
    #logmr "lf.maybeHide: left=#{o.left}; top=#{o.top}; width=#{w}; height=#{h}; x=#{x}; y=#{y}, isChild",
    isChild = (($ e.toElement)?.parents '.lf-picker').length > 0
    @hidePicker @ unless isChild or (x? and y? and o.left <= x <= o.left+w and o.top <= y <= o.top+h)
  hidePicker: (animation = @options.fadeOut, notify = true) -> unless isHidden = @isHidden()
    @picker.hide animation, =>
      @picker.removeClass('lf-modal lf-fullscreen lf-relative').css('left', '').css 'top', ''
      @container.removeClass 'lf-open'
      @config.onAfterHide?()
      @options.onAfterHide?()
      Meteor.liquidForm.onAfterHide?() # HACK: use event mechanism
    if (dataObj = @options.data)?
      dataObj = dataObj() if _.isFunction dataObj
      logmr 'lf.hidePicker: updated from form', u.updateFromForm @form, dataObj
    @update notify

  update: (notify = true) -> Deps.nonreactive =>
    labels = if notify then @config.onChange() ? @config.labels?()
    else @config.labels?() ? @config.onChange()
    @updateLabels @parseLabels labels

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
    else @label.html logmr 'lf.updateLabels: invalid labels', labels

  getModeClass: (isFullscreen = @isFullscreen()) -> if isFullscreen then 'lf-fullscreen' else 'lf-relative'
  isFullscreen: ->
    if (f = @options.fullscreen)? or (f = @config.fullscreen)? then f
    else Meteor.responsive.deviceHandheld() or (@picker.width()*1.5 > (d = $ document).innerWidth()) or (@picker.height()*1.5 > d.innerHeight())

class LiquidFormModal extends OpenClosed
  constructor: (@container) ->
    @container.addClass('lf-modal').data 'lfModal', @
    unless @container? and @container.length > 0
      return loge "LiquidForm: modal not found", @container
    super @container, not @container.data().manual

    later =>
      @container.toggleClass 'lf-fullscreen', Meteor.responsive.deviceHandheld()
      do @open
