if (!window.Visualforce) Visualforce = {};
if (!Visualforce.Mobile) Visualforce.Mobile = {};
$V = Visualforce.Mobile;

/**
 * Simple JavaScript Inheritance
 * By John Resig http://ejohn.org/
 * MIT Licensed.
 */
(function(){
    var initializing = false, fnTest = /xyz/.test(function(){xyz;}) ? /\b_super\b/ : /.*/;
    // The base Class implementation (does nothing)
    $V.Class = function(){};

    // Create a new Class that inherits from this class
    $V.Class.extend = function(prop) {
        var _super = this.prototype;

        // Instantiate a base class (but only create the instance,
        // don't run the init constructor)
        initializing = true;
        var prototype = new this();
        initializing = false;

        // Copy the properties over onto the new prototype
        for (var name in prop) {
          // Check if we're overwriting an existing function
          prototype[name] = typeof prop[name] == "function" &&
            typeof _super[name] == "function" && fnTest.test(prop[name]) ?
            (function(name, fn){
              return function() {
                var tmp = this._super;

                // Add a new ._super() method that is the same method
                // but on the super-class
                this._super = _super[name];

                // The method only need to be bound temporarily, so we
                // remove it when we're done executing
                var ret = fn.apply(this, arguments);
                this._super = tmp;

                return ret;
              };
            })(name, prop[name]) :
            prop[name];
        }

        // The dummy class constructor
        function Class() {
          // All construction is actually done in the init method
          if ( !initializing && this.init )
            this.init.apply(this, arguments);
        }

        // Populate our constructed prototype object
        Class.prototype = prototype;

        // Enforce the constructor to be what we expect
        Class.prototype.constructor = Class;

        // And make this class extendable
        Class.extend = arguments.callee;

        return Class;
    };
})();

/*
 * Copyright (c) 2012, salesforce.com <http://salesforce.com> , inc.
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com <http://salesforce.com> , inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

(function($) {
    // Extending jQuery for more functions.
    $.extend({
        getUrlVars: function(){
            var vars = [], hash;
            var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
            for(var i = 0; i < hashes.length; i++) {
              hash = hashes[i].split('=');
              vars.push(hash[0]);
              vars[hash[0]] = hash[1];
            }
            return vars;
        },
        getUrlVar: function(name){
            return $.getUrlVars()[name];
        }
    });
    
    /**
     * Application controller managing application lifecycle including managing pages and components
     */
    $V.App = (function() {
        // privates
        //TODO: Consider renaming config to compState
        var init = function(config) {
                this.config = config;
                this.pages = {};
                this.compIdtoCtlrMap = {};
                this.debug = this.config.debug;
                this.nextPage = {};
    
                function parseHash(hash) {
                    var idx;
                    if (hash) {
                        // FIXME: use regex
                        idx = hash.indexOf('#');
                        if (idx > -1) {
                            hash = hash.substring(idx + 1);
                        }
                        idx = hash.indexOf('?');
                        if (idx > -1) {
                            hash = hash.substring(0, idx);
                        }
                    }
                    return hash;
                }
    
                // listeners; wrap to give $V.App scope
                (function(that) {
                $(document).bind("pagebeforeload", function(evt, context) {
                    if (evt.target) {
                    that.log.debug('pagebeforeload: ' + (context && context.url ? context.url : 'unknown'));
                    }
                });
    
                // invoke page lifecycle for re-rendering (called every time a page is requested)
                $(document).bind("pagebeforechange", function(evt, context) {
                    var toPage, page;
                    if (evt.target && context) {
                        toPage = context && context.toPage && context.toPage.length > 0 ? context.toPage[0].id : null;
                        that.log.debug('pagebeforechange: ' + (toPage ? toPage : 'unknown'));
                        $V.App.nextPage = toPage;
                        if (toPage) {
                            page = that.getPage(parseHash(toPage));
                            // render page
                            if (page && page.rerender) {
                                that.log.debug('Rerendering page: ' + page.config.elemId);
                                page.rerender();
                            }
                        }
                    }
                });
    
                // invoke page lifecycle for creating page instance (first visited)
                $(document).bind("pagebeforecreate", function(evt, context) {
                    var page;
                    if (evt.target && evt.target.id) {
                        that.log.debug('pageinit: ' + (evt.target.id ? evt.target.id : 'unknown'));
                        if (evt.target.id) {
                            page = that.getPage(evt.target.id);
                            if (page && !(page instanceof $V.Page)) {
                                page = new $V.Page(page);
                                that.pages[page.config.elemId] = page;
                                that.log.debug('Init\'ing page: ' + page.config.elemId);
                            }
                        }
                    }
                });
    
                // invoke page lifecycle for rendering page for the first time
                $(document).bind("pageinit", function(evt, context) {
                    var page;
                    if (evt.target && evt.target.id) {
                        that.log.debug('pageinit: ' + (evt.target.id ? evt.target.id : 'unknown'));
                        if (evt.target.id) {
                            page = that.getPage(evt.target.id);
                            if (page && page.render) {
                                that.log.debug('Rendering page: ' + page.config.elemId);
                                page.render();
                            }
                        }
                    }
                });
    
                $(document).bind("pagechange", function(evt, context) {
                    var page;
                    if (evt.target) {
                    page = context && context.toPage && context.toPage.length > 0 ? context.toPage[0].id : null;
                        that.log.debug('pagechange: ' + (page !== null ? page : 'unknown'));
                        if (page) {
                            page = that.getPage(page);
                            if (page && page.postrender) page.postrender();
                        }
                    }
                });
    
                $(document).bind("pagechangefailed", function(evt, context) {
                    if (evt.target) {
                        that.log.debug('pagechangefailed: ' + (context && context.toPage ? context.toPage : 'unknown'));
                    }
                });
    
                if (that.config.debug === true) {
                    // Hook for remoting before call
                    Visualforce.remoting.RemotingProvider.on('beforecall',function(pdr,tx,m){
                        that.log.debug('VF Remoting beforecall', tx.data);
                    });
                }
            })(this);
        },
        registerPage = function(elemId, page) {
            if (!elemId) {
                //JQM adds a page automatically if no page found.
                this.log.info('Ignore page registration. No elemId parameter specified.'); 
                return;
            }
            
            page = page || this.pages[elemId] || new $V.Page(elemId);
            if (!(page instanceof $V.Page)) throw Error('Page must be an instance of $V.Page.');
            if (elemId != page.config.elemId) throw Error('Id and Page config elemId must match.'); 
            
            this.pages[elemId] = page;
                            
            return page;
        },
        // 1) Store component element Id and its JS controller.
        // 2) Attach component to a page.
        // 3) Pull fields from component and save to config.
        registerComponent = function(elemId, config) {
            var $parentPage, page, compCtlrFn, handlerFnExt, compCtlr;
            
            //FIXME: elemId = component.id, which is on config.elemId. Why not just use that?
            config.elemId = elemId || config.elemId;
            if (!config.elemId) throw Error('Component must have elemId');
            
            //The user specified a JS function name to use as JS controller - find it.
            compCtlrFn = $V.App.getFn(config.jsCtlrName);
            if (!compCtlrFn) throw Error('Component handler function is not defined or not found (' + config.jsCtlrName + ')');
            if (this.compIdtoCtlrMap[config.elemId]) return; // avoid re-registering same component
            
            // Create a new instance of the JS controller, passing its config.
            compCtlr = new compCtlrFn(config);
            if (!(compCtlr instanceof $V.Component)) throw Error('Component handler must extend Visualforce.Mobile.Component');
            this.compIdtoCtlrMap[config.elemId] = compCtlr;//Save the component controller for later.
            
            // Register it under its parent page. This App just deals in rendering whole pages.
            $parentPage = $('[id="'+ config.elemId + '"]').parents('[data-role="page"]:first');
            if ($parentPage.length) page = this.pages[$parentPage.attr('id')] || this.registerPage($parentPage.attr('id'));
            if (page) {
                page.comps.push(compCtlr);
            }
    
            console.log('compCtlr: ', compCtlr);
            // Save Salesforce fields on the component's config object for later reference.
            // 'sFieldNames' vs 'allfields'? Seems like allfields is for layout.
            // 'sFieldNames' is on SObjectConfig.
            //TODO: Check if we can remove this section. Not sure why this fields info
            //   would ever be stored on the compCtlr...
            if (compCtlr.fields) {
                if (!this.config.fields) this.config.fields = [];
                for (var i=0, len=compCtlr.fields.length; i<len; i++) {
                    if ($.inArray(compCtlr.fields[i], this.config.fields) == -1) this.config.fields.push(compCtlr.fields[i]);
                }
                delete compCtlr.fields;
            }
        },
        prepare = function() {
            // change viewport designation
            $('span').removeClass('ui-mobile-viewport');
            $('#'+this.config.elemId).addClass("ui-mobile-viewport");
            $.mobile.pageContainer = $('#'+this.config.elemId);
    
            // fetch user metadata
            $V.App.getFn(this.config.serverCtlrName).getUser(
                (function(that) {
                    return function(result, event) {
                        if (event.status && result && !result.errors) {
                            that.config.user = result;
                        } else {
                            $V.App.handleRemoteErrs(result, event, null, true);
                        }
                    };
                })(this)
            );
    
            // fetch field metadata
            if (this.config.fields && this.config.fields.length > 0) {
            $V.App.getFn(this.config.serverCtlrName).getFieldMetadata(
                    this.config.fields,
                    (function(that) {
                        return function(result, event) {
                            if (event.status && result && !result.errors) {
                                that.config.fields = result;
                                that.log.debug('Field metadata', that.config.fields);
                            } else {
                                $V.App.handleRemoteErrs(result, event, null, true);
                            }
                        };
                    })(this)
                );
            }
            
            //Render each component using its JS controller.
            if ($.isEmptyObject(this.pages) && !$.isEmptyObject(this.compIdtoCtlrMap)) {
                for (compId in this.compIdtoCtlrMap) {
                    this.compIdtoCtlrMap[compId].render();
                }
            } 
        },
        getPage = function(pageId) {
            return this.pages[pageId];
        },
        getFn = function (name, context) {
            if (!name) return null;
            context = context || window;
            var namespaces, func = name;
            if (name.indexOf('.') > -1) {
                namespaces = name.split(".");
                func = namespaces.pop();
                for (var i = 0; i < namespaces.length; i++) {
                    context = context[namespaces[i]];
                }
            }
            return context[func];
        },
        // utils
        log = {
            prefix: 'Mobile VF: ',
            info: function(msg, obj) {
                msg = this.prefix + msg;
                if (console && console.log && console.groupCollapsed && console.groupEnd) {
                    if (obj) {
                        console.groupCollapsed(msg);
                        console.log(JSON.stringify(obj, undefined, 2));
                        console.groupEnd();
                    } else {
                        console.log(msg);
                    }
                }
            },
            debug: function(msg, obj) {
                if ($V.App && $V.App.debug && $V.App.debug == true) this.info(msg, obj);
            },
            error: function(msg, obj) {
                if (console && console.error) {
                    console.error(msg, obj);
                }
            }
        },
        toObject = function(arr) {
            if (!$.isArray(arr)) return arr;
            var rv = {};
            for (var i = 0; i < arr.length; ++i)
                if (arr[i] !== undefined) rv[arr[i]] = null;
            return rv;
        },
        getFieldVal = function(rec, fieldPath) {
            var fieldSplit = fieldPath.split('\.');
            if (fieldSplit.length > 1) {
                return getFieldVal(rec[fieldSplit[0]], fieldPath.substring(fieldSplit[0].length+1));
            }
            return rec[fieldSplit[0]];
        },
        getFieldValTemplate = function(fieldPath) {
            var fieldParts = fieldPath.split('.'),
                temp = '${' + fieldPath + '}';
                
            if (fieldParts.length > 1) {
                while (fieldParts.pop() && fieldParts.length) {
                    temp = ('{{if ' + fieldParts.join('.') + '}}' + temp + '{{/if}}');
                }
            }
            return temp;
        },
        // messages
        handleRemoteErrs = function(result, event, $el, display) {
            var markup = [], msg;
            markup.push('Errors:');
            if(event.status && result && !result.success) {
                if (result.errors) {
                    for (var i=0, len=result.errors.length; i < len; i++) {
                        markup.push('<br/>');
                        markup.push(result.errors[i].message);
                    }
                } else {
                    markup.join(' Unknown');
                }
            } else {
                markup.push(event.message, ' ', event.where);
            }
            msg = markup.join('');
            if (display && display === true) $V.App.displayMsgs(msg);
            if ($el && $el.trigger) $el.trigger('error', event, result);
            this.log.info(msg);
        },
        displayMsgs = function(msg) {
            //FIX:Needs to fix
        },
        clearMsgs = function() {
			//FIX:Needs to fix
        }; 
        // end var
    
        return {
            init: init,
            registerPage: registerPage,
            registerComponent: registerComponent,
            prepare: prepare,
            // utils
            debug: false,
            currentPage: null,
            getPage: getPage,
            getFn: getFn,
            log: log,
            toObject: toObject,
            getFieldVal: getFieldVal,
            getFieldValTemplate: getFieldValTemplate,
            // msgs
            handleRemoteErrs: handleRemoteErrs,
            displayMsgs: displayMsgs,
            clearMsgs: clearMsgs
        };
    }());
    
    /**
     * Base class for components.  Extend this class for custom components.
     */
    $V.Component = $V.Class.extend({
        init: function(config) {
            this.config = config || {};
            if (!config.elemId) throw Error('Component\'s config must have an elemId property.');
            this.$me = $('[id="'+ config.elemId + '"]');
            if (!this.$me) throw Error('Element does not exist: ' + config.elemId);
        },
        prepare: function() {
            // to be implemented by extending class
            // any lazy loading that's required before render call
            this.prepared = true;
        },
        render: function() {
            this.prepare();
            // to be implemented by extending class
        },
        getContext: function() {
            return this.context;
        },
        parseField: function(field) {
            var idx = field.indexOf('.');
            if (idx > -1) return field.split('.');
            return [ null, field ];
        }
    });
    
})(jQuery);
