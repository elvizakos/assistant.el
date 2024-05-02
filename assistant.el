(require 'request)

;; curl -X POST http://192.168.68.8:11435/api/generate -d '{
;; "model" : "yi",
;; "prompt" : "Why is the sky blue?"
;; }'

(setq
 ;;assistant-server-url "http://192.168.68.8:11435/api/generate"
 assistant-server-url "http://lvzcms.debian.home.lan/tests/requests?f=json"
 assistant-model "yi"
 assistant-prompt "Why is the sky blue?"
 )

(request
  assistant-server-url
  :type "POST"

  :data  (json-encode (list (cons "model" assistant-model)
							(cons "prompt" assistant-prompt)))
  ;; :data  (json-encode `(("model" . ,assistant-model)
  ;; 						("prompt" . ,assistant-prompt)))

  :headers '(("Content-Type" . "application/json"))
  :parser 'json-read

  :success (cl-function
			(lambda (&key data &allow-other-keys)
			  ;;(message ">> %S" (assoc-default 'form data))
			  ;; (message "%s" data)
			  (with-current-buffer (get-buffer-create "**TESTS**")
				(erase-buffer)
				(insert (format "%s" data))
				)
			  ))

  :error (cl-function
		  (lambda (&key error-thrown &allow-other-keys&rest _)
			(message "Error: %S" error-thrown)
			))

  :complete (lambda (&rest _) (message "Finished!"))

  :status-code '((400 . (lambda (&rest _) (message "Got 400")))
				 (418 . (lambda (&rest _) (message "Got 418")))
				 (200 . (lambda (&rest _) (message "Got 200")))
				 )
  )
