class Editor

  measurements:
    toolbar:
      height: 0

  timer: false
  editableSection: null
  allowDelete: true

  document: document

  constructor: (el) ->
    @el = el
    @setup()
    @bindEvents()

  setup: ->
    @container = $('<div class="editor-container" />')
    @toolbar = $("
      <span class='editor-toolbar'>
        <a href='#' data-command='formatBlock' data-value='h1'>H1</a>
        <a href='#' data-command='formatBlock' data-value='h2'>H2</a>
        <a href='#' data-command='formatBlock' data-value='h3'>H3</a>
        <a href='#' data-command='insertList' data-value='ul'>UL</a>
        <a href='#' data-command='insertList' data-value='ol'>OL</a>
        <a href='#' data-command='formatBlock' data-value='p'>P</a>
        <a href='#' data-command='formatInline' data-value='bold'>B</a>
        <a href='#' data-command='formatBlock' data-value='p' data-append='img.right'>P+IMG</a>
        <a href='#' data-command='formatBlock' data-value='pre'>Code</a>
      </span>
    ")
    @el.wrap(@container)
    @toolbar.insertAfter(@el)

    @measurements.toolbar.height = @toolbar.height()
    @el.attr('contenteditable', true)

  bindEvents: ->
    @el.on('keydown', @onKeyDown)
    @el.on('keyup', @onKeyUp)
    @el.delegate('.editor-section', 'mouseover', @onSectionOver)
    @el.delegate('.editor-section', 'mouseout', @onSectionOut)
    @toolbar.delegate('a[data-command]', 'click', @onToolbarAction)
    @toolbar.on('mouseover', @onToolbarOver)
    @toolbar.on('mouseout', @onToolbarOut)

    @el.delegate('.img-box','dragenter.dropImage', @noOpEvent)
    @el.delegate('.img-box','dragexit.dropImage', @noOpEvent)
    @el.delegate('.img-box','dragover.dropImage', @noOpEvent)
    @el.delegate('.img-box','drop.dropImage', @onDrop)

  onKeyDown: (e) =>
    if e.which <= 90 and e.which >= 48
      @allowDelete = true
    if e.keyCode is 13 and !e.metaKey and !e.ctrlKey
      setTimeout(@ensureNewBlockIsParagraph, 1, e)
    if e.keyCode is 9
      @addNestedList()
      e.preventDefault()
    if e.keyCode is 8
      e.preventDefault() unless @allowDelete
    true

  onKeyUp: (e) =>
    if e.keyCode is 8
      @allowDelete = @safeDeletion()

  onSectionOver: (e) =>
    @clearSectionHover(false)
    @editableSection = $(e.target)
    @editableSection = @editableSection.parents('.editor-section') unless @editableSection.hasClass('editor-section')
    pos = @editableSection.position()
    @toolbar.css({top:pos.top - @measurements.toolbar.height / 2})

  onSectionOut: (e) =>
    clearTimeout(@timer) if @timer
    @timer = setTimeout(@clearSectionHover, 400, true)

  clearSectionHover: (hide) =>
    clearTimeout(@timer) if @timer
    @timer = false
    @editableSection = null
    @toolbar.css({top:-300}) if hide

  onToolbarOver: (e) =>
    clearTimeout(@timer) if @timer

  onToolbarOut: (e) =>
    @onSectionOut()

  onToolbarAction: (e) =>
    e.stopPropagation()
    e.preventDefault()
    tgt = $(e.target)
    command = tgt.data('command')
    arg = tgt.data('value')
    append = tgt.data('append') or null
    switch command
      when 'formatBlock' then @formatBlock(arg, append)
      when 'insertList' then @insertList(arg)
      when 'formatInline' then @formatInline(arg)

  formatBlock: (tag, append = null) ->
    node = @editableSection.get(0)
    @editableSection.find('.img-box').each( (i, el) -> $(el).remove())
    if node.tagName.toLowerCase() is tag
      el = @editableSection
    else
      @focusCaretOnNode(node)
      html = @editableSection.text()
      newBlock = $("<#{tag} class='editor-section' />").html(html)
      @editableSection.replaceWith(newBlock)
      @editableSection = newBlock
      @focusCaretOnNode(newBlock.get(0))

    @appendToBlock(el, append) if append isnt null

  appendToBlock: (el, append) ->
    parts = append.split('.')
    tag = parts[0]
    arg = parts[1]
    if tag is 'img'
      a = $("<span class='img-box float-#{arg}'></span>")
      el.prepend(a)

  formatInline: (arg) ->
    t = @getSelectedText()
    if t.length isnt 0
      document.execCommand(arg)

  insertList: (tag) ->
    c = @editableSection.find(':first-child')
    if c and (c.prop('tagName') is 'UL' or c.prop('tagName') is 'OL')
      html = c.html()
    else
      html = "<li>#{@editableSection.html()}</li>"
    newNode = $("<div class='editor-section'><#{tag}>#{html}</#{tag}></div>")
    @editableSection.replaceWith(newNode)
    li = newNode.find('li')
    @focusCaretOnNode(li.get(0))
    @editableSection = newNode

  focusCaretOnNode: (node) ->
    range = rangy.createRange()
    range.setStart(node, 0)
    range.setEnd(node, 1)
    range.collapse(false)
    rangy.getSelection().addRange(range)

  ensureNewBlockIsParagraph: (e) =>
    selection = rangy.getSelection()
    range = selection.getRangeAt(0)
    node = range.commonAncestorContainer
    if node.nodeName.toLowerCase() isnt 'p'
      possibleParent = $(node.parentNode)
      parentIsEditor = possibleParent.get(0) is @el.get(0)
      parentIsSection = possibleParent.hasClass('editor-section')
      if parentIsEditor or parentIsSection
        n = $(node)
        newP = $('<p class="editor-section">&nbsp;</p>')
        n.replaceWith(newP)
        newP.insertAfter(possibleParent) if parentIsSection
        @focusCaretOnNode(newP.get(0))
        newP.html('')

  checkNewNode: =>
    selection = rangy.getSelection()
    range = selection.getRangeAt(0)
    pn = $(range.commonAncestorContainer)
    if pn.prop('tagName') is 'DIV'
      div = pn.parents('.editor-section')
      newNode = $('<p class="editor-section"></p>').html(pn.html())
      div.after(newNode)
      pn.remove()
      selection = rangy.getSelection()
      range = selection.getRangeAt(0)
      range.collapse(false)
      range = range.cloneRange()
      range.setStart(newNode.get(0), 0)
      range.setEnd(newNode.get(0), 1)
      selection.removeAllRanges()
      selection.addRange(range)

  addNestedList: ->
    selection = rangy.getSelection()
    range = selection.getRangeAt(0)
    pn = $(range.commonAncestorContainer)
    pn = pn.parents('li') if pn.prop('tagName') isnt 'LI'
    if pn.prop('tagName') is 'LI'
      document.execCommand('Indent')

  safeDeletion: ->
    selection = rangy.getSelection()
    range = selection.getRangeAt(0)
    pn = $(range.commonAncestorContainer.parentNode)
    pn = pn.parents('.editor-section') unless pn.hasClass('editor-section')
    html = pn.html()
    hasContent = html?.trim().length > 0 or false
    children = @el.children().length
    if children is 0
      newNode = $('<p class="editor-section">&nbsp;</p>')
      newNode.appendTo(@el)
      selection = rangy.getSelection()
      range = selection.getRangeAt(0)
      range.setStart(newNode.get(0), 0)
      range.setEnd(newNode.get(0), 1)
      selection.removeAllRanges()
      selection.addRange(range)
    children > 1 || hasContent

  noOpEvent: (e) ->
    e.stopPropagation()
    e.preventDefault()

  onDrop: (e) =>
    e.stopPropagation()
    e.preventDefault()
    box = $(e.target)
    box = box.parents('.img-box') unless box.hasClass('img-box')

    files = e.originalEvent.dataTransfer.files
    if files.length > 0
      reader = new FileReader()
      reader.onload = (evt) =>
        dataURI = evt.target.result
        box.html('<img src="'+dataURI+'" />')

      reader.readAsDataURL(files[0])

  getSelectedText: ->
    if document?.selection
      document.selection.createRange().text
    else
      document.getSelection().toString()

  log: () ->
    console?.log.apply console, arguments

window.Editor = Editor