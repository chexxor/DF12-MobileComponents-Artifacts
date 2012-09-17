(function($) {

    /**
     * Class representing list components and their lifecycle.  Extend to override standard list component functionality.
     */
    $V.ThumbnailListController = $V.Component.extend({
    
        // Component.init override.
        init: function(config) {
            this._super(config);
            
            // Attach event listeners.
            $(document).on('listitemselect', function(e, context) {
                // Add some behavior when item is selected.
            });
        },
        
        // Component.render override.
        render: function() {
            this._super();
            
            // Load records from the server, and give it a function to handle the response.
            $.mobile.showPageLoadingMsg();
            // Maybe move requestRecords to 'prepare'.
            // TODO: Find this requestRecordsHandler
            var serverRecords = this.requestRecords(this.requestRecordsHandler);
            $.mobile.hidePageLoadingMsg();
            
        },
        
        requestRecords: function(responseHandler) {
            $V.App.log.debug('this.config: ', this.config);
            
            //JS Remoting
            //To allow dynamic server controller
            // - 'getFn(this.config.serverCtlrName)' => 'ThumbnailListController'
            $V.App.getFn(this.config.serverCtlrName).getRecordsForConfig(
                this.config //Pass JS controller state to Apex controller.
                ,
                // Callback
                (function(that, fn) {
                    return function(result, event) {
                            fn.apply(that, arguments);
                            //$.mobile.hidePageLoadingMsg();
                        };
                })(this, responseHandler)
            );
            
        },
        
        requestRecordsHandler: function(result, event) {
            // See what the response looks like.
            $V.App.log.debug(this.config.serverCtlrName + '.getRecords response: ', result);
            
            // JSON response may not have same structure as model on page.
            // Transform the response list of records to match the HTML template.
            var modelForTemplate = this.parseModelFromJsonResponse(result);
            
            // 3) Push the data into template.
            // This component has a dependency that a window variable
            //   named 'rowItemTemplate' has a Mustache template.
            var rowItemTempl = window.rowItemTempl;
            var listItemsMarkup = Mustache.render(rowItemTempl, modelForTemplate);
            
            $V.App.log.debug('Template result: ', listItemsMarkup);
            
            // 4) Insert the markup into the DOM.
            $ul = this.$me.find('ul');
            $ul.html(listItemsMarkup);
            
            // 5) Re-apply jQuery Mobile styles and behavior.
            $ul.listview('refresh');
            
            // After mark up is rendered, reapply any custom events
            //   to the new elements.
            this.applyEvents($ul);
        },
        
        // Helper method for requestRecordsHandler.
        // Transforms response JSON to match the JS page model.
        parseModelFromJsonResponse: function(jsonResponse) {
            
            // Our mustache template can parse an array, but it must
            //   have a name.
            // So, simply copy all records into an object
            //   property names 'records'.
            var model = {};
            model.records = [];
            for (var i = 0; i < jsonResponse.length; i++) {
                var record = jsonResponse[i];
                $V.App.log.debug('Received record: ', record);
                model.records.push(record)
            }
            $V.App.log.debug('Finished model: ', model);
            return model;
        },
        
        // Helper method for requestRecordsHandler method.
        // Current actions:
        // a) Attach 'listitemselect' event to each element for framework to listen for.
        applyEvents: function($el) {
            $el.tap(
                (function(comp) {
                    return function(e) {
                        var data, $target = $(e.target).closest('li', comp.$me);
                        //e.preventDefault();
                        if ($target && !$target.is('[data-role="list-divider"]')) {
                            comp.$me.removeClass('cellselected');
                            $target.addClass('cellselected');
                            //data = [{config: {stype: comp.config.sObjectType, nextPage: comp.config.nextPage}, data: comp.records[$target.attr('data-item-context')]}];
                            $(document).trigger('listitemselect', data);
                            $target.trigger('hide');
                        }
                    }
                })(this));
        }
        
    });
    
})(jQuery);
