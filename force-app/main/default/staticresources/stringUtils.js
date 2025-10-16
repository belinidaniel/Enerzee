/**
 * String utility functions.
 * @namespace stringUtils
 */
window.stringUtils = (function () {
  /**
   * Formats a string.
   * @param s {string} The format string, e.g. 'Example {0} string {1}'.
   * @param arguments {...*} Replacement arguments.
   * @returns {string} The formatted string.
   */
  var format = function (s) {
    if (s) {
      var outerArguments = arguments;
      return s.replace(/{(\d+)}/g, function () {
        return outerArguments[parseInt(arguments[1]) + 1];
      });
    }
    return '';
  };

  /**
   * Formats a byte size. For example, 2048 bytes will be formatted as '2 kB'.
   * @param size {number} The size in bytes.
   * @param precision {number} Decimal precision [default 2].
   * @returns {string} The formatted size string.
   */
  var formatSize = function (size, precision) {
    if (!size || typeof size !== 'number' || size < 0) {
      return '0 B';
    }

    var constant = 1024;
    var p = precision || 2;
    var exponents = ['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    var factor = Math.floor(Math.log(size) / Math.log(constant));

    return parseFloat((size / Math.pow(constant, factor)).toFixed(p)) + ' ' + exponents[factor];
  };

  /**
   * Unescapes an HTML string, i.e. '&amp;' will be replaced with '&', '&lt;' with '<', and '&gt;' with '>'.
   * @param s {string} The HTML to unescape.
   * @returns {string} The unescaped HTML.
   */
  var unescapeHtml = function (s) {
    if (!s) {
      return '';
    }
    return s.replace(/&quot;/g, '"')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&#39;/g, '\'');
  };

  /**
   * Escapes HTML in a string.
   * @param s {string} The string to HTML-escape.
   * @returns {string} The escaped HTML.
   */
  var escapeHtml = function (s) {
    if (!s) {
      return '';
    }
    return s.replace(/&quot;/g, '"')
      .replace('/&/g', '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  };

  /**
   * Formats an error message from an HTTP response.
   * @param response {Response} The HTTP response.
   * @returns {string} The formatted error message.
   */
  var getErrorMessage = function (response) {
    var message = '';
    if (!$A.util.isUndefinedOrNull(response) && !$A.util.isUndefinedOrNull(response.getError)) {
      var errors = response.getError();
      message = errors;
      if (!$A.util.isEmpty(errors)) {
        message = errors[0].message;
      }
    }

    if ($A.util.isEmpty(message)) {
      message = $A.get('$Label.c.UnknownError');
    }
    return message;
  };

  /**
   * Formats an error exception type from an HTTP response.
   * @param response {Response} The HTTP response.
   * @returns {string} The exception type.
   */
  var getExceptionType = function (response) {
    var type = '';
    if (!$A.util.isUndefinedOrNull(response) && !$A.util.isUndefinedOrNull(response.getError)) {
      var errors = response.getError();
      if (!$A.util.isEmpty(errors)) {
        type = errors[0].exceptionType;
      }
      if ($A.util.isEmpty(type)) {
        type = '';
      }
    }

    return type;
  };

  /**
   * Formats a message as HTML.
   * @param message {string|string[]} The message to format.
   * @returns {string} The HTML-formatted string.
   */
  var formatHtml = function (message) {
    if ($A.util.isEmpty(message)) return '';

    var result;
    if (Array.isArray(message)) {
      result = '<ul>';
      for (var i = 0; i < message.length; i++) {
        result += '<li>' + escapeHtml(message[i]).replace('\n', '<br/>') + '</li>'
      }
      result += '</ul>';
    } else {
      result = escapeHtml(message).replace('\n', '<br/>');
    }
    return result;
  };

  /**
   * Formats a message as HTML.
   * @param fileGuid {string} The SCM file ID.
   * @param fileName {string} The name of the file.
   * @param extension {string} The file extension.
   * @param size {number} The file size.
   * @returns {string} The formatter SCM file string containing all information
   */
  var formatSCMFile = function (fileGuid, fileName, extension, size) {
    return format('scm;{0};{1};{2};{3}', fileGuid || '', fileName || '', extension || '', size || '');
  };

  if (!String.prototype.startsWith) {
    Object.defineProperty(String.prototype, 'startsWith', {
      value: function(search, rawPos) {
        var pos = rawPos > 0 ? rawPos|0 : 0;
        return this.substring(pos, pos + search.length) === search;
      }
    });
  }

  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(search, this_len) {
      if (this_len === undefined || this_len > this.length) {
        this_len = this.length;
      }
      return this.substring(this_len - search.length, this_len) === search;
    };
  }

  /**
   * Sanitizes custom object names to respect customer privacy.
   * @param objName The Salesforce object name.
   * @returns {string} The sanitized object name.
   */
  var sanitizeObjectName = function (objName) {
    if (!objName) return 'Unknown Object';

    var lcn = objName.toLowerCase();
    return lcn.endsWith('__c') && !lcn.startsWith('sbqq') && !lcn.startsWith('blng') ? 'Custom Object' : objName;
  }

  /**
   * Returns a byte integer value into megabytes (MB).
   * @param size The integer value measured in bytes.
   * @returns {number} The size in megabytes rounded to the nearest tenth.
   */
  var getSizeInMegabytes = function (size) {
    return size <= 0 ? 0 : Math.round(size / 100000) / 10;
  }

  return Object.freeze({
    format: format,
    formatSize: formatSize,
    formatHtml: formatHtml,
    escapeHtml: escapeHtml,
    unescapeHtml: unescapeHtml,
    getErrorMessage: getErrorMessage,
    getExceptionType: getExceptionType,
    formatSCMFile: formatSCMFile,
    sanitizeObjectName: sanitizeObjectName,
    getSizeInMegabytes: getSizeInMegabytes
  });
}());
Quicklinks
Profiles Chamber
Quick Console
Home
Quick Query
Execute Anonymous
Sobject fields
Quick ORG Describe
Replace API Names
Convert SF Id
Login As...
Options
Hide
Learn Apex Now