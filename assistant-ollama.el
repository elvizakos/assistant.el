(defun assistant/-ollama-api-points () "Returns the URL API points for ollama"
		   (list "api/generate"
			 "api/chat"
			 "api/tags"
			 "api/embeddings"))

(defun assistant/--get-list-of-models-ollama ( data ) "Analyze the ollama api json and get the list of models."
	   (mapcar (lambda (item) "Walk through models array"
				 (let ((model-name (cdr  (assoc 'name item))))
				   (assistant/--db-add-model-to-db (nth 0 assistant/with-current-api) model-name)
				   (list :model model-name :api-n assistant/with-current-api-n)))
				 (cdr (assoc 'models data))))

(defun assistant/--request-chat-ollama ( chat message provider protocol hostname port chaturl apikey success-callback error-callback complete-callback) "Function for handling the request for the ollama api."
	   (let* ((url (concat protocol
						   hostname ":" (number-to-string port) "/"
						   (replace-regexp-in-string
							"%%API-KEY%%"
							apikey
							chaturl)))
			  (json "")
			  (messagehistory (assistant/--db-get-message-history (plist-get chat :title))))

		 (setq json (json-encode (list (cons 'model (plist-get chat :model))
									   (cons 'messages messagehistory)
									   (cons 'stream :json-false)
									   )))
		 (request url
		   :type "POST"
		   :data json
		   :headers '(("Accept" . "application/json")
					  ("Content-Type" . "application/json"))
		   :success success-callback
		   :error error-callback
		   :complete complete-callback
		   )))

(defun assistant/--request-models-list-ollama ( provider protocol hostname port path apikey ) "Function to get the list of models for the Ollama API."
	   (let* ((url (concat protocol
						   hostname ":" (number-to-string port)
						   "/"
						   path)) ; Build the URL and store it in url variable
			  )

		 ;; Make the request
		 (request url
		   :type "GET"
		   :headers '(("Accept" . "application/json"))
		   :error (cl-function (lambda (&key error-thrown &allow-other-keys&rest _) (error "Error: %S" error-thrown)))
		   :complete (lambda (&rest _) (message "Getting model list for \"ollama\" finished!"))
		   :success (cl-function
					 (lambda (&key data &allow-other-keys) "If the request succeeds, analyze it and store the list of models."
					   (let ((modeldata (json-parse-string data :object-type 'alist))
							 )

						 (if (fboundp 'assistant/--get-list-of-models-ollama)
							 (setq assistant/models-list (delete-dups (append assistant/models-list (assistant/--get-list-of-models-ollama modeldata))))
						   (error "API ollama isn't loaded")))))
		   )))

(defun assistant/--chat-response-ollama ( str ) "Analyze the chat response and return list with the data."
	   (let* ((msg (gethash "message" str))
			  (role (gethash "role" msg))
			  (cont (gethash "content" msg)))
		 cont))

(provide 'assistant-ollama)
