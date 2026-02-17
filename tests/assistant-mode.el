;;; assistant-mode.el --- Minor mode for getting help and chat with ollama and other AI.
;;; -*- coding: utf-8 -*-

;; Version: %%VERSION%%
;; Author: Nikos Skarmoutsos <elvizakos AT yahoo DOT gr>
;; Maintainer: Nikos Skarmoutsos
;; Created: May 2024
;; Keywords: ai,gpt,chatgpt,llama,ollama,assistant,gemini,lm studio
;; License: GNU General Public License >=2
;; Distribution: This file is not part of Emacs

;;; Code:

;;---- FACES ----------------------------------------------------------------------

;;---- CONSTANTS ------------------------------------------------------------------
(defconst assistant/assistant-version "%%VERSION%%" "Assistant version.")

;;---- VARIABLES ------------------------------------------------------------------
(defvar assistant/assistant-keymap (make-sparse-keymap) "Keymap for assistant.")

(defvar assistant/models-list nil "List of all models.")

(defvar assistant/chat-list nil "List of open chats with all of their properties.")

(defvar assistant/active-chat nil "Current active chat")

(defvar assistant/pending-responses 0 "Variable for defining the number of pending requrests.")

(defvar assistant/--lighter (propertize " A" 'face 'assistant/done-requests-face) "Variable for setting the string and text properties of the lighter.")

(defvar assistant/db-history nil "Database object.")

(defvar assistant/$buffer nil "The assistant's chat buffer.")

;;---- OPTIONS --------------------------------------------------------------------
(defgroup assistant nil "Assistant minor mode settings."
  :group 'tools)

(defcustom assistant/lighter " A" "Label of minor mode for the modeline."
  :type 'string
  :group 'assistant)

(defcustom assistant/lighter-ready-color "green" "The color of the minor mode's lighter, when it is ready."
  :type 'color
  :group 'assistant)

(defcustom assistant/lighter-unread-color "blue" "The color of the minor mode's lighter, when it is ready and have unread messages."
  :type 'color
  :group 'assistant)

(defcustom assistant/lighter-busy-color "red" "The color of the minor mode's lighter, when it expects for a response."
  :type 'color
  :group 'assistant)

(defcustom assistant/buffer-name "** ASSISTANT **" "The name of the assistant's buffer."
  :type 'string
  :group 'assistant)

(defcustom assistant/default-chat-model nil "The default mode for chat."
  :type 'string
  :group 'assistant)

(defcustom assistant/api-subscriptions '() "API keys from various services."
  :type '(repeat (list (string :tag "Subscription name")
					   (choice :tag "Api type"
							   (const :tag "Ollama" "ollama")
							   (const :tag "LM-Studio" "lm-studio")
							   (const :tag "Open-WebUI" "openwebui")
							   (const :tag "Perplexica" "perplexica")
							   (const :tag "OpenAI V1" "openai-v1")
							   (const :tag "Google Gemini" "google-gemini-v1beta")
							   )
					   (choice :tag "Protocol"
							   (const :tag "HTTPS" "https://")
                               (const :tag "HTTP" "http://"))
					   (string :tag "Host name")
					   (integer :tag "Port")
					   (string :tag "Generate URL path")	;; Use %%MODEL%% for the model. Use %%API-KEY%% for the api key.
					   (string :tag "Chat URL path")		;; Use %%MODEL%% for the model. Use %%API-KEY%% for the api key.
					   (string :tag "Model list URL path")	;; List of available models. Use %%API-KEY%% for the api key.
					   (string :tag "Embedding URL path")	;; Use for embeddings Use %%MODEL%% for the model. Use %%API-KEY%% for the api key.
                       (string :tag "API key")
					   (repeat :tag "HTTP Headers" (list (string :type "Header name")
														 (string :type "Header value")))
                       ))
  :group 'assistant)

(defcustom assistant/keep-history t "Option to keep chat history or not."
  :type 'boolean
  )

(defcustom assistant/history-path "~/.emacs.d/assistant-history" "Path to the directory of saved conversations"
  :type 'directory
  )

(defcustom assistant/history-type "sqlite3" "How is going to keep the chat history."
  :type '(choice (const "Markdown File")
                 (const "sqlite3"))
  )

(defcustom assistant/assistant-activate-chat-keycomb "C-x / ?" "Default key combination for activating the chat buffer."
  :type 'string
  )

(defcustom assistant/assistant-continue-code-keycomb "C-x / /" "Default key combination for activating the chat buffer."
  :type 'string
  )

(defcustom assistant/assistant-activate-code-chat-keycomb "C-x / c" "Default key combination for activating the chat buffer."
  :type 'string
  )

(defcustom assistant/assistant-change-chat-model-keycomb "C-x c c" "Default key combination for activating the chat buffer."
  :type 'string
  )

(defcustom assistant/assistant-change-code-model-keycomb "C-x c m" "Default key combination for activating the chat buffer."
  :type 'string
  )

(defcustom assistant/assistant-toggle-buffer-keycomb "C-x / t" "Default key combination for activating the chat buffer."
  :type 'string
  )

;;---- FUNCTIONS ------------------------------------------------------------------

;; FUNCTIONS
(defun assistant/build-db () "Function to build the database table structure."
	   (sqlite-execute assistant/db-history "
CREATE TABLE apis (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT NOT NULL UNIQUE
);

CREATE TABLE models (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	api_id INTEGER NOT NULL,
	name TEXT NOT NULL,
	FOREIGN KEY ( api_id ) REFERENCES apis(id) ON DELETE CASCADE,
	UNIQUE(api_id, name)
);

CREATE TABLE chats (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	title TEXT DEFAULT ('Chat ' || strftime('%Y-%m-%d %H:%M:%S')),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	last_model INTEGER,
	FOREIGN KEY ( last_model ) REFERENCES models(id) ON DELETE SET NULL
);

CREATE TABLE messages (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	chat_id INTEGER NOT NULL,
	datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	participant_type CHECK(participant_type IN ('user', 'model')),
	participant_id INTEGER,
	contents TEXT,
	FOREIGN KEY ( chat_id ) REFERENCES chats(id) ON DELETE CASCADE,
	FOREIGN KEY ( participant_id ) REFERENCES models(id) ON DELETE SET NULL,
	CHECK (
		(participant_type = 'user' AND participant_id IS NULL) OR
		(participant_type = 'model' AND participant_id IS NOT NULL)
	)
);

-- Indexes
CREATE INDEX idx_models_api ON models(api_id);
CREATE INDEX idx_chats_last_model ON chats(last_model);
-- CREATE INDEX idx_messages_chat_id ON messages(chat_id);
CREATE INDEX idx_messages_participant_id ON messages(participant_id);
CREATE INDEX idx_messages_datetime ON messages(datetime);
CREATE INDEX idx_messages_chat_datetime ON messages(chat_id, datetime);
")
	   )

(defun assistant/activate-chat () "Activate chat buffer."
		   (interactive)
		   (message "Chat")
		   )

(defun assistant/toggle-chat-buffer () "Toggle chat buffer."
		   (interactive)
		   (message "Toggle chat buffer.")
		   )

(defun assistant/build-code () "Build code."
		   (interactive)
		   (message "Code")
		   )

(defun assistant/change-chat-model () "Set the LLM model to use for chat."
		   (interactive)
		   (message "Set chat model")
		   )

(defun assistant/change-code-model () "Set the LLM model to use for code."
		   (interactive)
		   (message "Set code model")
		   )

(defun assistant/--add-api-to-db ( api ) "Add and API to database if it's not already stored."
	   (sqlite-execute assistant/db-history "INSERT INTO apis ( name ) VALUES ( '?' );" '(api)))

(defun assistant/--add-model-to-db ( api model ) "Add a model to database if it's not already stored."
	   (sqlite-execute assistant/db-history "
INSERT INTO models ( api_id, name )
VALUES (
	(SELECT id FROM apis WHERE name = '?'),
	'?'
);
" '(api model)))

(defun assistant/load-chat-history ( chat &optional date ) "Function to load the chat history into chat buffer."
	   (let ((dt 0)
			 (msglist nil))
		 (if date (setq dt (format-time-string "%Y-%m-%d %H:%M:%S" date)))
		 (if assistant/keep-history
			 (if (file-exists-p assistant/history-path)
				 (progn
				   (assistant/build-buffer)
				   (with-current-buffer assistant/$buffer
					 (cond ;; ((string= assistant/history-type "Markdown File")
					  ;;  (progn
					  ;; 	(insert-file-contents (concat assistant/history-path "/history.md"))
					  ;; 	))
					  ((string= assistant/history-type "sqlite")
					   (progn
						 (erase-buffer)
						 (setq msglist (sqlite-select assistant/db-history "
SELECT m.datetime, COALESCE(md.name, 'USER') AS usr, m.contents
FROM messages m
INNER JOIN chats c ON c.id = m.chat_id
LEFT JOIN models md ON md.id = m.participant_id
WHERE c.title = ? AND datetime(m.datetime) >= datetime(?)
ORDER BY m.datetime ASC
;" '(chat dt)))
						 (dolist (row msglist)
						   (let* ((date (nth 0 row))
								  (username (nth 1 row))
								  (contents (nth 2 row)))
							 (assistant/add-chat-message username date contents)
							 ))
						 )))))))))

(defun assistant/--db-save-message-to-db ( chat model message &optional date ) "Function to add a message to the database."
  (let ((modelornull nil)
		(ptype nil))

	(if (string= model "user")
		(setq modelornull "(SELECT id FROM models WHERE name = '?')"
			  values '(chat "model" model message))
	  (setq modelornull ""
			values '(chat "user" message)))

	(sqlite-execute assistant/db-history (concat "
INSERT INTO messages (chat_id, participant_type, participant_id, contents)
VALUES (
    (SELECT id FROM chats WHERE title = '?'),
    '?',
    " modelornull ",
    '?'
);"
	values))))

(defun assistant/add-chat-message ( sender date message &optional style $buffer ) "Function to add a message to chat buffer."
	   (let (($b nil)
			 (s nil))
		 (if $buffer (setq $b $buffer) (setq $b assistant/$buffer))
		 (if style (setq s style) (setq s "minimal"))

		 (with-current-buffer $b

		   (cond ((string= s "minimal")
				  (insert (format "> **%s** — %s\n\n" username date))
				  (insert (format "%s\n\n---\n\n" contents)))
				 ))))

(defun assistant/--db-get-last-chat () "Function to get the last used chat."
	   (let ((chatlst nil))
		 (setq chatlst (sqlite-select assistant/db-history "
	   SELECT c.id, c.title
FROM messages m
INNER JOIN chats c ON c.id = m.chat_id
ORDER BY m.datetime DESC
LIMIT 1;"))
		 (if (> (length chatlst) 0) (nth 0 chatlst))
		 ))

(defun assistant/update-all-apis () "Function to update all APIs."
	   (setq assistant/models-list '()) ; Clear list of models
	   (when (and (boundp 'assistant/api-subscriptions) assistant/api-subscriptions)
		 (mapcar (lambda (sub) "Walk through api-subscriptions."
				   (assistant/get-list-of-models sub)) ; Add models from api subscription.
				 assistant/api-subscriptions)))

(defun assistant/get-list-of-models ( api ) "Function to return the list of models from a subscription."
	   (when (>= (length assistant/api-subscriptions) api) ; Check if item exists.
		 (let ((sbdata (nth api assistant/api-subscriptions)) ; Get item
			   ;; Get item's properties:
			   (provider "")
			   (apitype "")
			   (protocol "")
			   (hostname "")
			   (port 0)
			   (listpath "")
			   (apikey ""))

		   (setq provider (nth 0 sbdata)
				 apitype (nth 1 sbdata)
				 protocol (nth 2 sbdata)
				 hostname (nth 3 sbdata)
				 port (nth 4 sbdata)
				 listpath (nth 7 sbdata)
				 apikey (nth 9 sbdata))

		   ;; Build url
		   (setq url (concat protocol
							 hostname
							 ":"
							 (number-to-string port)
							 "/"
							 (replace-regexp-in-string "%%API-KEY%%" apikey listpath)))

		   ;; Create the request
		   (request url :type "GET"
			 :headers '(("Accept" . "application/json"))
			 :error (cl-function (lambda (&key error-thrown &allow-other-keys&rest _) (error "Error: %S" error-thrown)))
			 :complete (lambda (&rest _) (message "Getting model list for \"%s\" finished!" provider))
			 :success (cl-function
					   (lambda (&key data &allow-other-keys) "If the request succeeds, analyze it and store the list of models."
						 (let ((modeldata (json-parse-string data :object-type 'alist))
							   (getlistf (intern (concat "assistant/-get-list-of-models-" apitype))))
						   (if (fboundp getlistf)
							   (setq assistant/models-list (delete-dups (append assistant/models-list (funcall getlistf modeldata))))
							 (error "API %s isn't loaded" apitype)) )))
			 )))
	   nil)

(defun assistant/update-lighter () "Update the mode's lighter based on the status of the pending requests."
		   (interactive)
		   (if (> assistant/pending-responses 0)
			   ;; Pending requests
			   (setq minor-mode-alist
				 (cons '(assistant-mode
						 (:eval (concat (propertize assistant/lighter
													'face
													`(:background ,assistant/lighter-busy-color :weight bold))
										;; " "
										;; (propertize (concat "(" (number-to-string assistant/pending-responses) ")")
										;; 			'face
										;; 			'((:foreground "blue" :weight normal :height 0.4)
										;; 			  default))
										)
								))
					   (assq-delete-all 'assistant-mode minor-mode-alist)))
		 ;; Ready
		 (setq minor-mode-alist
			   (cons '(assistant-mode
					   (:eval (concat (propertize assistant/lighter
												  'face
												  `(:background ,assistant/lighter-ready-color :weight normal))
									  ;; " "
									  ;; (propertize (concat "(" (number-to-string assistant/pending-responses) ")")
									  ;; 			  'face
									  ;; 			  '((:foreground "blue" :weight normal :height 0.4)
									  ;; 				default))
									  )
							  ))
					 (assq-delete-all 'assistant-mode minor-mode-alist)))))

(defun assistant/build-buffer () "Function to build the chat buffer."
	   (setq assistant/$buffer (get-buffer-create assistant/buffer-name))
	   (with-current-buffer assistant/$buffer
		 (rename-buffer assistant/buffer-name)
		 (markdown-mode)
		 (if (commandp 'linum-mode) (linum-mode 0) (line-number-mode 0))
		 (toggle-truncate-lines 0))
	   assistant/$buffer)

(defun assistant/split-window () "Function to split frame if there is no second window."
	   (let ((otherwindow nil)
			 (currentwindow nil)
			 (lastchat (assistant/--db-get-last-chat))
			 (maxpos 0))
		 (if (one-window-p) (split-window-right))
		 (if (not (get-buffer assistant/buffer-name)) (progn
														(assistant/build-buffer)
														(if lastchat (assistant/load-chat-history lastchat))
														))
		 (setq currentwindow (selected-window)
			   otherwindow (window-next-sibling))
		 (set-window-buffer otherwindow assistant/$buffer)

		 ))

(defun assistant/--scroll-buffer-to-bottom () "Function to scroll the chat window to the bottom of chat buffer."
	   (with-current-buffer assistant/$buffer
		 (point (point-max))))

;; Load the plugins
(setq assistant/load-path (file-name-as-directory (directory-file-name (file-name-directory (or load-file-name buffer-file-name)))))
(setq assistant/load-ollama t)
(setq assistant/load-openwebui t)
(setq assistant/load-lmstudio t)
(if assistant/load-ollama (load (concat assistant/load-path "assistant-ollama.el")))
(if assistant/load-openwebui (load (concat assistant/load-path "assistant-openwebui.el")))
(if assistant/load-lmstudio (load (concat assistant/load-path "assistant-lmstudio.el")))

;;---- MINOR MODE ------------------------------------------------------------------
(define-minor-mode assistant-mode "Assistant minor mode."
  :lighter assistant/--lighter
  :keymap (let ((assistantmap (make-sparse-keymap)))
			(require 'request)
			(require 'json)
			(require 'assistant-ollama)
			(require 'assistant-openwebui)
			(require 'assistant-lmstudio)

			;; Set database object
			(if (not (file-exists-p (concat assistant/history-path "/db.sqlite3")))
				;; If database file does not exists, create it, open
				;; it and build table structure
				(progn
				  ;; Create the directory if does not exist.
				  (if (not (file-exists-p (concat assistant/history-path))) (make-directory assistant/history-path))

				  ;; Create db file.
				  (setq assistant/db-history (sqlite-open (concat assistant/history-path "/db.sqlite3")))

				  ;; Build db structure.
				  (assistant/build-db))

			  ;; If database file exists, open it.
			  (setq assistant/db-history (sqlite-open (concat assistant/history-path "/db.sqlite3"))))

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Build models list
			;; (assistant/update-all-apis)

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; BUILD BUFFER
			(assistant/build-buffer)

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Build Lighter menu
			(define-key-after		 ; Menu for Assistant mode
			  assistant/assistant-keymap
			  [menu-bar assistantmenu]
			  (cons "Assistant" (make-sparse-keymap "assinstant mode"))
			  'kill-buffer)

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuaskchatbot]
						'("Chat" . assistant/activate-chat))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuaskcodebot]
						'("Build code" . assistant/build-code))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchangechatmodel]
						'("Change chat model" . assistant/change-chat-model))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchangecodemodel]
						'("Change code model" . assistant/change-code-model))

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Keyboard shortcuts

			(define-key assistant/assistant-keymap (kbd assistant/assistant-activate-chat-keycomb) 'assistant/activate-chat)

			;; (define-key assistant/assistant-keymap (kbd assistant/assistant-continue-code-keycomb) 'assistant/build-code)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-change-chat-model-keycomb) 'assistant/change-chat-model)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-change-code-model-keycomb) 'assistant/change-code-model)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-toggle-buffer-keycomb) 'assistant/toggle-chat-buffer)

			assistant/assistant-keymap)

  :global 1

  )

(assistant-mode 1)

(provide 'assistant-mode)
