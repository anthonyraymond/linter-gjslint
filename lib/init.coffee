{CompositeDisposable} = require 'atom'
{findFile, exec, tempFile} = helpers = require 'atom-linter'
path = require 'path'
XRegExp = require 'xregexp'

module.exports =
  config:
    executablePath:
      type: 'string'
      title: 'gjslint executable path'
      default: 'gjslint'
    gjslintIgnoreList:
      title: 'Google closure-linter error code to ignore'
      description: 'Codes from https://goo.gl/VAdwHE separated by commas.'
      type: 'array'
      default: []
      items:
        type: 'string'
    flags:
      type: 'array'
      default: []
      items:
        type: 'string'
  activate: ->
    require('atom-package-deps').install()
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'linter-gjslint.executablePath',
      (executablePath) =>
        @executablePath = executablePath
    @subscriptions.add atom.config.observe 'linter-gjslint.gjslintIgnoreList',
      (gjslintIgnoreList) =>
        @gjslintIgnoreList = gjslintIgnoreList
    @subscriptions.add atom.config.observe 'linter-gjslint.flags',
      (flags) =>
        @flags = flags
  deactivate: ->
    @subscriptions.dispose()
  buildMsg: (match, filePath, range) ->
    text = 'E:' + match.code + ' - ' + match.message
    return {
      text: text
      type: 'error'
      filePath: filePath
      range: range
    }

  provideLinter: ->
    helpers = require('atom-linter')
    provider =
      name: 'gjslint'
      grammarScopes: ['source.js', 'source.js.jquery', 'text.html.basic']
      scope: 'file'
      lintOnFly: true
      lint: (editor) =>
        filePath = editor.getPath()
        cwd = path.dirname(filePath)
        tempFile path.basename(filePath), editor.getText(), (tmpFilePath) =>
          params = @flags || []
          if @gjslintIgnoreList.length != 0
            errorsToDisable = @gjslintIgnoreList.join ','
            params = params.concat ('--disable=' + errorsToDisable)
          params = params.concat [
            '--nobeep',
            '--quiet',
            tmpFilePath
          ]
          return helpers.exec(@executablePath, params, {cwd}).then (stdout) =>
            regex = XRegExp '^(?<line>\\d+), E:(?<code>[^:]+): (?<message>.+)$',
              's'

            lines = stdout.split(/\nLine\s/)

            return [] unless lines.length

            messages = []

            lines.forEach (msg) =>
              XRegExp.forEach msg, regex, (match, i) =>
                range = helpers.rangeFromLineNumber(editor, match.line - 1)
                messages.push @buildMsg(match, filePath, range)

            return messages
