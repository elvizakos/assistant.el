;;; assistant.el --- Minor mode for getting help and chat with ollama and other AI.
;;; -*- coding: utf-8 -*-

;; Copyright © 2024, Nikos Skarmoutsos

;; Version: %%VERSION%%
;; Author: Nikos Skarmoutsos <elvizakos AT yahoo DOT gr>
;; Maintainer: Nikos Skarmoutsos
;; Created: May 2024
;; Keywords: string
;; License: GNU General Public License >=2
;; Distribution: This file is not part of Emacs

;;; Code:

;;---- CONSTANTS ------------------------------------------------------------------
(defconst assistant/assistant-version "%%VERSION%%" "Assistant version.")

;;---- VARIABLES ------------------------------------------------------------------
(defvar assistant/assistant-keymap (make-sparse-keymap) "Keymap for assistant.")

(defvar assistant/prompt "" "The user prompt.")

(defvar assistant/response "" "The assistant's response.")

(defvar assistant/$buffer nil "The assistant's buffer.")

;;---- OPTIONS --------------------------------------------------------------------
(defgroup assistant nil "Assistant minor mode settings."
  :group 'tools)

(defcustom assistant/lighter " A" "Label of minor mode for the modeline."
  :type 'string
  :group 'assistant)

(defcustom assistant/server-url "http://192.168.68.8:11434/api/generate" "The URL of the ollama."
  :type 'string
  :group 'assistant)

(defcustom assistant/chat-model "llama2:7b" "The model to be used for chat."
  :type 'string
  ;;:type '(choice (const :tag "codegemma:2b" "codegemma:7b" "codellama:7b" "gemma:2b" "gemma:7b" "llama2:7b" "llama2:latest" "llama2:text" "llama2-uncensored:7b" "orca-mini:latest" "phi3:latest" "qwen:0.5b" "qwen:1.8b" "starcoder2:3b" "starcoder2:7b" "starcoder2:latest" "tinydolphin:latest" "tinyllama:latest" "yi:latest"))
  :group 'assistant)

(defcustom assistant/coding-model "starcoder2:7b" "The model to be used for code completion."
  :type 'string
  ;;:type '(choice (const :tag "codegemma:2b" "codegemma:7b" "codellama:7b" "gemma:2b" "gemma:7b" "llama2:7b" "llama2:latest" "llama2:text" "llama2-uncensored:7b" "orca-mini:latest" "phi3:latest" "qwen:0.5b" "qwen:1.8b" "starcoder2:3b" "starcoder2:7b" "starcoder2:latest" "tinydolphin:latest" "tinyllama:latest" "yi:latest"))
  :group 'assistant)
;; '("codegemma:2b" "codegemma:7b" "codellama:7b" "gemma:2b" "gemma:7b" "llama2:7b" "llama2:latest" "llama2:text" "llama2-uncensored:7b" "orca-mini:latest" "phi3:latest" "qwen:0.5b" "qwen:1.8b" "starcoder2:3b" "starcoder2:7b" "starcoder2:latest" "tinydolphin:latest" "tinyllama:latest" "yi:latest")

(defcustom assistant/buffer-name "** ASSISTANT **" "The name of the assistant's buffer."
  :type 'string
  :group 'assistant)

;;---- FUNCTIONS ------------------------------------------------------------------

(defun assistant/json-get-response ( str )
  (let ((ar (split-string str "\n"))
		(i 0)
		(itm "")
		(res "")
		(done nil)
		(ret "")
		)
	(while (< i (+ 1 (length ar)))
	  (if (and (string= (type-of (nth i ar)) "string") (> (length (nth i ar)) 0) (string= (substring (nth i ar) 0 1) "{"))
		  (setq itm (json-parse-string (nth i ar))
				res (gethash "response" itm)
				done (gethash "done" itm))
		)
	  (setq i (1+ i)
			ret (concat ret res))
	  )
	ret))

(defun assistant/request ( model prompt ) "Function to get response "
	   (setq assistant/response ""
			 assistant/$buffer (get-buffer-create assistant/buffer-name))
	   ;; (set-buffer assistant/$buffer)
	   (other-window 1 t)
	   (switch-to-buffer assistant/$buffer)
	   (with-current-buffer assistant/$buffer
		 (erase-buffer)

		 (request
		   assistant/server-url
		   :type "POST"

		   :data  (json-encode (list (cons "model" model)
									 (cons "prompt" prompt)))
		   ;; :parser 'json-read

		   :headers '(("Accept" . "application/json")
					  ("Content-Type" . "application/json"))

		   :success (cl-function
					 (lambda (&key data &allow-other-keys)
						 (insert (assistant/json-get-response data))))

		   :error (cl-function
				   (lambda (&key error-thrown &allow-other-keys&rest _)
					 (error "Error: %S" error-thrown)
					 ))

		   :complete (lambda (&rest _) (message "Finished!"))

		   ;; :status-code '((400 . (lambda (&rest _) (message "Got 400")))
		   ;; 				(418 . (lambda (&rest _) (message "Got 418")))
		   ;; 				(200 . (lambda (&rest _) (message "Got 200")))
		   ;; 				)
		   ))
	   nil
	   )

;;---- MINOR MODE ------------------------------------------------------------------
(define-minor-mode assistant-mode "Assistant minor mode."
  :lighter assistant/lighter
  :keymap (let ((assistantmap (make-sparse-keymap)))
			(require 'request)
			(require 'json)

			(setq assistant/$buffer (get-buffer-create assistant/buffer-name))
			;; (setq assistant/$buffer (get-buffer-create assistant/buffer-name))
			

			assistant/assistant-keymap)
  :global 1

  (make-local-variable 'assistant/assistant-keymap))

(assistant-mode 1)

(provide 'assistant-mode)
