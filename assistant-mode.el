;;; assistant-mode.el --- Minor mode for getting help and chat with ollama and other AI.
;;; -*- coding: utf-8 -*-

;; Copyright © 2024, Nikos Skarmoutsos

;; Version: %%VERSION%%
;; Author: Nikos Skarmoutsos <elvizakos AT yahoo DOT gr>
;; Maintainer: Nikos Skarmoutsos
;; Created: May 2024
;; Keywords: ai,gpt,chatgpt,llama,ollama,assistant
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

(defvar assistant/$codeBuffer nil "The buffer to use for writing code")

(defvar assistant/bufferpoint 0 "The last position of cursor.")

(defvar assistant/models-list nil "List of all models.")

(defvar assistant/coding-models-list nil "List of coding models.")

;;---- OPTIONS --------------------------------------------------------------------
(defgroup assistant nil "Assistant minor mode settings."
  :group 'tools)

(defcustom assistant/assistant-ask-chatbot-keycomb "C-x / ?" "Default key combination for asking the chat bot."
  :type 'string
  :group 'assistant
  )

(defcustom assistant/assistant-continue-code-keycomb "C-x / /" "Default key combination for asking the bot to continue code."
  :type 'string
  :group 'assistant
  )

(defcustom assistant/assistant-ask-codebot-keycomb "C-x / c" "Default key combination for asking the bot for code."
  :type 'string
  :group 'assistant
  )

(defcustom assistant/assistant-change-chat-model-keycomb "C-x c c" "Default key combination for changing chat model."
  :type 'string
  :group 'assistant
  )

(defcustom assistant/assistant-change-coding-model-keycomb "C-x c m" "Default key combination for changing coding model."
  :type 'string
  :group 'assistant
  )

(defcustom assistant/lighter " A" "Label of minor mode for the modeline."
  :type 'string
  :group 'assistant)

(defcustom assistant/server-url "http://192.168.68.8:11434/api/generate" "The URL of the ollama."
  :type 'string
  :group 'assistant)

(defcustom assistant/chat-model "qwen:0.5b" "The model to be used for chat."
  :type 'string
  ;;:type '(choice (const :tag "codegemma:2b" "codegemma:7b" "codellama:7b" "gemma:2b" "gemma:7b" "llama2:7b" "llama2:latest" "llama2:text" "llama2-uncensored:7b" "orca-mini:latest" "phi3:latest" "qwen:0.5b" "qwen:1.8b" "starcoder2:3b" "starcoder2:7b" "starcoder2:latest" "tinydolphin:latest" "tinyllama:latest" "yi:latest"))
  :group 'assistant)

(defcustom assistant/coding-model "starcoder2:3b" "The model to be used for code completion."
  :type 'string
  ;;:type '(choice (const :tag "codegemma:2b" "codegemma:7b" "codellama:7b" "gemma:2b" "gemma:7b" "llama2:7b" "llama2:latest" "llama2:text" "llama2-uncensored:7b" "orca-mini:latest" "phi3:latest" "qwen:0.5b" "qwen:1.8b" "starcoder2:3b" "starcoder2:7b" "starcoder2:latest" "tinydolphin:latest" "tinyllama:latest" "yi:latest"))
  :group 'assistant)

(defcustom assistant/buffer-name "** ASSISTANT **" "The name of the assistant's buffer."
  :type 'string
  :group 'assistant)

;;---- FUNCTIONS ------------------------------------------------------------------

(defun assistant/split-window () "Function to split window if there is no second window."
	   (let ((otherwindow nil)
			 (currentwindow nil)
			 (maxpos 0))
		 (if (one-window-p) (split-window-right))

		 (setq currentwindow (selected-window)
			   otherwindow (window-next-sibling)
			   assistant/$buffer (get-buffer-create assistant/buffer-name))
		 (set-window-buffer otherwindow assistant/$buffer)
		 (with-current-buffer assistant/$buffer
		   ;; (erase-buffer)
		   (markdown-mode)
		   (setq maxpos (point-max))
		   (goto-char (point-max))

		   (set-window-point
			(get-buffer-window (current-buffer) 'visible)
			(point-max))
		   (linum-mode 0)
		   (toggle-truncate-lines 0)
		   )
		 ))

(defun assistant/chat-window-scroll-to-bottom () "Function to scroll the chat window to the bottom"
	   (let ((chatwindow (get-buffer-window assistant/$buffer))
			 (maxpos 0))
		 (with-current-buffer assistant/$buffer
		   (setq maxpos (point-max)))
		 (set-window-point chatwindow maxpos)
		 ))

(defun assistant/json-get-response ( str ) "Get response from server and turn it to string"
  (let ((ar (split-string str "\n"))
		(i 0)
		(itm "")
		(res "")
		(done nil)
		(model "")
		(ret "")
		)
	(while (< i (+ 1 (length ar)))
	  (if (and (string= (type-of (nth i ar)) "string") (> (length (nth i ar)) 0) (string= (substring (nth i ar) 0 1) "{"))
		  (setq itm (json-parse-string (nth i ar))
				model (gethash "model" itm)
				res (gethash "response" itm)
				done (gethash "done" itm))
		)
	  (setq i (1+ i)
			ret (concat ret res))
	  )
	;; (concat model " - " ret)
	ret ))

(defun assistant/request ( model prompt ) "Function to get response "
	   (setq assistant/response "")

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
					 (with-current-buffer assistant/$buffer
					   (goto-char (point-max))
					   (insert (assistant/json-get-response data))
					   (assistant/chat-window-scroll-to-bottom)
					   )))

		 :error (cl-function
				 (lambda (&key error-thrown &allow-other-keys&rest _)
				   (error "Error: %S" error-thrown)
				   ))

		 :complete (lambda (&rest _) (message "Finished!"))

		 ;; :status-code '((400 . (lambda (&rest _) (message "Got 400")))
		 ;; 				(418 . (lambda (&rest _) (message "Got 418")))
		 ;; 				(200 . (lambda (&rest _) (message "Got 200")))
		 ;; 				)
		 )
	   nil)

(defun assistant/requestCode ( model prompt ) "Function to get response for creating code in current buffer."
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
					 (with-current-buffer assistant/$codeBuffer
					   (goto-char assistant/bufferpoint)
					   (insert (assistant/json-get-response data))
					   (read-only-mode nil))))

		 :error (cl-function
				 (lambda (&key error-thrown &allow-other-keys&rest _)
				   (error "Error: %S" error-thrown)
				   ))

		 :complete (lambda (&rest _) (message "Finished!"))

		 )
	   nil)

(defun assistant/askchatbot () "Function to ask the chat bot"
	   (interactive)
	   (assistant/split-window)
	   (let ((userinput (read-string ">>> ")))
		 (with-current-buffer assistant/$buffer
		   (goto-char (point-max))
		   (insert (format "\n\n------------------------------\n\n**YOU (%s)** - %s\n\n**%s (%s)** - " (format-time-string "%d-%m-%Y %H:%M:%S") userinput assistant/chat-model (format-time-string "%d-%m-%Y %H:%M:%S"))))
		 (assistant/request assistant/chat-model userinput)
		 ))

(defun assistant/askcoder () "Function to ask the coder bot and get code."
	   (interactive)
	   (let ((userinput (read-string ">>> ")))
		 ;; (assistant/request assistant/chat-model userinput)
		 ))

(defun assistant/continue-from-here () "Function to continue the code the user is writing after the cursor."
	   (interactive)
	   (setq assistant/$codeBuffer (window-buffer)
			 assistant/bufferpoint (point))
	   (let ((userinput (buffer-substring-no-properties 1 (point))))
		 (with-current-buffer assistant/$codeBuffer
		   (read-only-mode -1))
		 (message "Wait . . .")
		 (assistant/requestCode assistant/coding-model userinput)
		 ))

(defun assistant/change-chatbot () "Interactive function to change the chatbot in use."
	   (interactive)
	   (setq assistant/chat-model (ido-completing-read "Select name of the AI: " assistant/models-list)))

(defun assistant/change-coder () "Interactive function to change the coder ai in use."
	   (interactive)
	   (setq assistant/coding-model (ido-completing-read "Select name of the AI: " assistant/models-list)))

;;---- MINOR MODE ------------------------------------------------------------------
(define-minor-mode assistant-mode "Assistant minor mode."
  :lighter assistant/lighter
  :keymap (let ((assistantmap (make-sparse-keymap)))
			(require 'request)
			(require 'json)

			(setq assistant/models-list '("codegemma:2b" "codegemma:7b" "codellama:7b" "gemma:2b" "gemma:7b" "llama2:7b" "llama2:latest" "llama2:text" "llama2-uncensored:7b" "orca-mini:latest" "phi3:latest" "qwen:0.5b" "qwen:1.8b" "starcoder2:3b" "starcoder2:7b" "starcoder2:latest" "tinydolphin:latest" "tinyllama:latest" "yi:latest"))

			;; (setq assistant/$buffer (get-buffer-create assistant/buffer-name))
			;; (setq assistant/$buffer (get-buffer-create assistant/buffer-name))
			;;;;;;;; Lighter menu
			(define-key-after		 ; Menu for Assistant mode
			  assistant/assistant-keymap
			  [menu-bar assistantmenu]
			  (cons "Assistant" (make-sparse-keymap "assinstant mode"))
			  'kill-buffer)

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuaskchatbot]
			  '("Ask bot" . assistant/askchatbot))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuaskcoder]
			  '("Ask for code" . assistant/askcoder))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenucontinuefromhere]
			  '("Continue from here" . assistant/continue-from-here))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchatechatbot]
			  '("Change chat model" . assistant/change-chatbot))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchangecoder]
			  '("Change coder model" . assistant/change-coder))

			;;;;;;;; Keyboard shortcuts
			(define-key assistant/assistant-keymap (kbd assistant/assistant-ask-chatbot-keycomb) 'assistant/askchatbot)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-continue-code-keycomb) 'assistant/continue-from-here)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-change-chat-model-keycomb) 'assistant/change-chatbot)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-change-coding-model-keycomb) 'assistant/change-coder)

			assistant/assistant-keymap)
  :global 1

  (make-local-variable 'assistant/assistant-keymap))

(assistant-mode 1)

(provide 'assistant-mode)
