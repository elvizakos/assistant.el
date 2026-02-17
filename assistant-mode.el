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

(defvar assistant/active-chat-model nil "Current active chat model.")

(defvar assistant/chat-list nil "List of open chats with all of their properties.")

(defvar assistant/active-chat nil "Current active chat")

(defvar assistant/pending-responses 0 "Variable for defining the number of pending requrests.")

(defvar assistant/--lighter " A" "Variable for setting the string and text properties of the lighter.")

(defvar assistant/db-history nil "Database object.")

(defvar assistant/$buffer nil "The assistant's chat buffer.")

(defvar assistant/window-register nil "Buffer layout.")

(defvar assistant/with-current-api nil "Variable to store the current working API object.")

(defvar assistant/with-current-api-n nil "Variable to store the current working API's index in assistant/api-subscriptions.")

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

(defcustom assistant/window-size 30 "The window's width."
  :type 'number
  :group 'assistant)

(defcustom assistant/split-direction "vertical" "The direction to split the window when opening the chat buffer."
  :type 'string
  :group 'assistant)

;; --- History

(defcustom assistant/keep-history t "Option to keep chat history or not."
  :type 'boolean
  :group 'assistant)

(defcustom assistant/chat-message-style "minimal" "The style of each message in the chat."
  :type '(choice (const "minimal")
                 (const "minimal-headers"))
  :group 'assistant)

(defcustom assistant/history-path "~/.emacs.d/assistant-history" "Path to the directory of saved conversations"
  :type 'directory
  :group 'assistant)

(defcustom assistant/history-type "sqlite3" "How is going to keep the chat history."
  :type '(choice (const "Markdown File")
                 (const "sqlite3"))
  :group 'assistant)

;; --- Keyboard shortcuts
(defcustom assistant/assistant-activate-chat-keycomb "C-x / ?" "Default key combination for activating the chat buffer."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-continue-code-keycomb "C-x / /" "Default key combination for activating the chat buffer."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-activate-code-chat-keycomb "C-x / c" "Default key combination for activating the chat buffer."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-new-chat "C-x / c n" "Default key combination for creating a new conversation."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-select-chat "C-x / c c" "Default key combination for selecting a conversation."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-select-chat-model-keycomb "C-x / c m" "Default key combination for selecting an LLM model for the chat."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-change-code-model-keycomb "C-x c m" "Default key combination for activating the chat buffer."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-toggle-buffer-keycomb "C-x / t" "Default key combination for activating the chat buffer."
  :type 'string
  :group 'assistant)

(defcustom assistant/assistant-set-window-size-keycomb "C-x / w" "Default key combination for setting the size of the chat window."
  :type 'string
  :group 'assistant)

;;---- FUNCTIONS ------------------------------------------------------------------

;; FUNCTIONS
(defun assistant/--db-build-db () "Function to build the database table structure."
	   (sqlite-execute assistant/db-history "
CREATE TABLE apis (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	name TEXT NOT NULL UNIQUE
);")

	   (sqlite-execute assistant/db-history "
CREATE TABLE models (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	api_id INTEGER NOT NULL,
	name TEXT NOT NULL,
	prompt TEXT,
	FOREIGN KEY ( api_id ) REFERENCES apis(id) ON DELETE CASCADE,
	UNIQUE(api_id, name)
);")

	   (sqlite-execute assistant/db-history "
CREATE TABLE chats (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	title TEXT DEFAULT ('Chat ' || strftime('%Y-%m-%d %H:%M:%S')),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	last_model INTEGER,
	prompt TEXT,
	FOREIGN KEY ( last_model ) REFERENCES models(id) ON DELETE SET NULL
);")

	   (sqlite-execute assistant/db-history "
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
);")

	   ;; -- Indexes
	   (sqlite-execute assistant/db-history "CREATE INDEX idx_models_api ON models(api_id);")
	   (sqlite-execute assistant/db-history "CREATE INDEX idx_chats_last_model ON chats(last_model);")
	   ;;-- CREATE INDEX idx_messages_chat_id ON messages(chat_id);
	   (sqlite-execute assistant/db-history "CREATE INDEX idx_messages_participant_id ON messages(participant_id);")
	   (sqlite-execute assistant/db-history "CREATE INDEX idx_messages_datetime ON messages(datetime);")
	   (sqlite-execute assistant/db-history "CREATE INDEX idx_messages_chat_datetime ON messages(chat_id, datetime);")
	   )

;; ---- API functions
(defun assistant/update-all-apis () "Function to update all APIs."
	   (let ((i 0))
		 (setq assistant/models-list '()) ; Clear list of models
		 (when (and (boundp 'assistant/api-subscriptions) assistant/api-subscriptions)
		   (mapcar (lambda (sub) "Walk through api-subscriptions."
					 (assistant/--db-add-api-to-db sub)
					 (assistant/get-list-of-models sub)) ; Add models from api subscription.
				   assistant/api-subscriptions))))

(defun assistant/--db-add-api-to-db ( api ) "Add and API to database if it's not already stored."
	   (sqlite-execute assistant/db-history "INSERT OR IGNORE INTO apis ( name ) VALUES ( ? );" (list (nth 0 api))))

;; ---- Models functions
(defun assistant/select-chat-model () "Set the LLM model to use for chat."
	   (interactive)
	   (let* ((model-names (mapcar (lambda (itm) (plist-get itm :model)) assistant/models-list))
			  (selection (completing-read "Select chat model: " model-names nil t))
			  (pmodel (nth (cl-position selection model-names :test 'string=) assistant/models-list))
			  (api-n (plist-get pmodel :api-n)))
		 (setq assistant/with-current-api-n api-n
			   assistant/with-current-api (nth api-n assistant/api-subscriptions)
			   assistant/active-chat-model selection)))

(defun assistant/change-code-model () "Set the LLM model to use for code."
		   (interactive)
		   (message "Set code model")
		   )

(defun assistant/get-list-of-models ( api ) "Function to return the list of models from a subscription."
	   (let ((provider (nth 0 api))
			  (apitype (nth 1 api))
			  (protocol (nth 2 api))
			  (hostname (nth 3 api))
			  (port (nth 4 api))
			  (listpath (nth 7 api))
			  (apikey (nth 9 api)))
		 (setq assistant/with-current-api api
			   assistant/with-current-api-n (cl-position api assistant/api-subscriptions :test 'equal))

		 (funcall (intern (concat "assistant/--request-models-list-" apitype ))
				  provider
				  protocol
				  hostname
				  port
				  listpath
				  apikey))
	   nil)

(defun assistant/--db-add-model-to-db ( api model ) "Add a model to database if it's not already stored."
	   (sqlite-execute assistant/db-history "INSERT OR IGNORE INTO models ( api_id, name ) VALUES ( (SELECT id FROM apis WHERE name = ?), ? );" (list api model)))

;; ---- Chat & chat messages functions
(defun assistant/new-chat () "Interactive function for creating a new chat."
	   (interactive)
	   (let* ((title (read-string "Set chat title (empty for auto generate): ")))
		 (if (string= title "") (setq title nil))
		 (message "%S" (assistant/--db-new-chat title))))

(defun assistant/select-chat () "Interactive function for selecting a conversation."
	   (interactive)
	   (let ((prev-chat assistant/active-chat)
			 (chat-list (sqlite-select assistant/db-history "SELECT title FROM chats;")))
		 (setq assistant/active-chat (completing-read "Select chat: " chat-list nil t))
		 ;; If the chat has changed:
		 (if (not (string= assistant/active-chat prev-chat))
			 (progn
			   (with-current-buffer assistant/$buffer (erase-buffer))
			   (assistant/--refresh-chat-buffer)
			   ))))

(defun assistant/delete-chat () "Interactive function for deleting a chat."
	   )

(defun assistant/add-chat-message ( sender date message &optional style $buffer ) "Function to add a message to chat buffer."
	   (let (($b nil)
			 (s nil))
		 (if $buffer (setq $b $buffer) (setq $b assistant/$buffer))
		 (if style (setq s style) (setq s assistant/chat-message-style))

		 (setq date (cond ((and (listp date) date) date)
						  ((stringp date) (date-to-time date))
						  ((numberp date) (seconds-to-time date))
						  (t date)))

		 (with-current-buffer $b
		   (goto-char (point-max))
		   (cond ((string= s "minimal")
				  (insert (format "> **%s** — %s\n\n" sender (format-time-string "%d-%m-%Y %H:%M:%S" date)))
				  (insert (format "%s\n\n---\n\n" message)))
				 ((string= s "minimal-headers")
				  (insert (format "# **%s** — %s\n\n" sender (format-time-string "%d-%m-%Y %H:%M:%S" date)))
				  (insert (format "%s\n\n---\n\n" message)))
				 ))))

;; ---- Chat history functions
(defun assistant/--db-load-chat-history ( chat &optional date messages-before ) "Function to load the chat history into chat buffer."
	   (let ((dt 0)
			 (msglist nil)
			 (sql "")
			 (values (list chat))
			 (prevsqlquery "")
			 (wdate ""))

		 (if date (setq dt (format-time-string "%Y-%m-%d %H:%M:%S" date)
						wdate "AND datetime(m.datetime) >= datetime(?)"
						values (list chat dt)))

		 (if messages-before
			 (setq prevsqlquery (concat "SELECT m.datetime, COALESCE(md.name, 'USER') AS usr, m.contents FROM ( SELECT * FROM messages WHERE datetime < datetime('" dt "') ORDER BY datetime DESC LIMIT " (number-to-string messages-before)" ) m INNER JOIN chats c ON c.id = m.chat_id LEFT JOIN models md ON md.id = m.participant_id WHERE c.title = ? UNION ALL")
				   values (cons chat values)))

		 (if assistant/keep-history
			 (if (file-exists-p assistant/history-path)
				 (progn
				   (if (not assistant/$buffer) (assistant/--build-buffer))
				   (with-current-buffer assistant/$buffer
					 (cond ;; ((string= assistant/history-type "Markdown File")
					  ;;  (progn
					  ;; 	(insert-file-contents (concat assistant/history-path "/history.md"))
					  ;; 	))
					  ((string= assistant/history-type "sqlite3")
					   (progn
						 (erase-buffer)
						 (setq sql (concat prevsqlquery "
SELECT
	m.datetime,
	COALESCE(md.name, 'USER') AS usr,
	m.contents
FROM
	messages m
INNER JOIN chats c ON c.id = m.chat_id
LEFT JOIN models md ON md.id = m.participant_id
WHERE c.title = ? " wdate "
ORDER BY m.datetime ASC
;"))

						 (setq msglist (sqlite-select assistant/db-history sql values))
						 (dolist (row msglist)
						   (let* ((date (nth 0 row))
								  (username (nth 1 row))
								  (contents (nth 2 row)))
							 (assistant/add-chat-message username date contents)
							 ))
						 )))))))))

(defun assistant/--db-save-message-to-db ( chat model message &optional date ) "Function to add a message to the database."
	   (let ((modelornull nil)
			 (cols "")
			 (sql "")
			 (values ""))

		 (if (string= model "user")
			 (setq modelornull ""
				   cols "chat_id, participant_type, contents"
				   values (list chat "user" message))
		   (setq modelornull "(SELECT id FROM models WHERE name = ?),"
				 cols "chat_id, participant_type, participant_id, contents"
				 values (list chat "model" model message)))

		 (setq sql (concat "
INSERT INTO messages (" cols ")
VALUES (
    (SELECT id FROM chats WHERE title = ?),
    ?, " modelornull " ?
);"))
		 (sqlite-execute assistant/db-history sql values)))

(defun assistant/--db-get-last-chat () "Function to get the last used chat."
		   (let ((chatlst nil))
		 (setq chatlst (sqlite-select assistant/db-history "
SELECT c.id, c.title
FROM chats c
LEFT JOIN messages m ON m.chat_id = c.id
GROUP BY c.id
ORDER BY COALESCE(MAX(m.datetime), c.created_at) DESC
LIMIT 1;"))
		 (if (> (length chatlst) 0) (nth 0 chatlst))))

(defun assistant/--db-get-chat-info ( id-or-title ) "Function to get info of a chat from database."
	   (let* ((sql "
SELECT
	c.title AS title,
	COALESCE(c.prompt, m.prompt) AS prompt,
	m.name AS model
FROM
	chats c
LEFT JOIN
	models m ON c.last_model = m.id
")
			  (model nil)
			  (result nil))
		 (if (string= (type-of id-or-title) "string")
			 (setq sql (concat sql "WHERE c.title = ?"))
		   (setq sql (concat sql "WHERE c.id = ?")))
		 (setq sql (concat sql " LIMIT 1;"))
		 (setq result (sqlite-select assistant/db-history sql (list id-or-title)))
		 (if (> (length result) 0)
			 (progn
			   (setq result (nth 0 result))
			   (if (and (not assistant/active-chat-model) model)
				   (setq model (nth 2 result))
				 (setq model assistant/active-chat-model))
			   (if (not model) (progn
								 (assistant/select-chat-model)
								 (setq model assistant/active-chat-model)))
			   (list :title (nth 0 result)
					 :prompt (nth 1 result)
					 :model model)))))

(defun assistant/--db-get-last-model () "Function to get the last used model."
	   (let ((models (sqlite-select assistant/db-history "
SELECT md.name
FROM models md
INNER JOIN messages ms ON ms.participant_id = md.id
ORDER BY ms.datetime DESC
LIMIT 1;")))
		 (if (> (length models) 0) (nth 0 models))))

(defun assistant/--db-new-chat ( &optional title ) "Function to create new chat instance."
	   (let ((last-id nil))
		 (if (and title (string= (type-of title) "string"))
			 (sqlite-execute assistant/db-history "INSERT OR IGNORE INTO chats ( title ) VALUES ( ? );" (list title))
		   (sqlite-execute assistant/db-history "INSERT INTO chats DEFAULT VALUES;"))
		 (setq last-id (sqlite-select assistant/db-history "SELECT id FROM chats ORDER BY id DESC LIMIT 1;"))
		 (if last-id (nth 0 (nth 0 last-id)))))

(defun assistant/--db-get-message-history ( chat &optional until-date max-messages ) "Function to get messages from database for use in requests."
	   (let* ((until-date (cond ((numberp until-date)(concat " AND msg.datetime  <= datetime('" (number-to-string until-date) "', 'unixepoch')"))
								((stringp until-date)(concat " AND msg.datetime  <= datetime('" until-date "')"))))
			  (max-messages (if (numberp max-messages) (number-to-string max-messages) "20"))
			  (sql (concat "
SELECT * FROM (
SELECT
	CASE
		WHEN msg.participant_type = 'user' THEN 'user'
		ELSE 'assistant'
	END AS role,
	msg.contents AS contents,
	msg.datetime AS datetime
FROM
	messages msg
INNER JOIN chats c ON c.id = msg.chat_id
WHERE " (if (stringp chat) "c.title = ?" "c.id = ?")
until-date " ORDER BY msg.datetime DESC LIMIT 0," max-messages "
) ORDER BY datetime ASC;"
))
			  (r nil))

		 (setq r (sqlite-select assistant/db-history sql (list chat)))
		 (mapcar (lambda (itm)
				   (list (cons 'role (nth 0 itm))
						 (cons 'content (nth 1 itm))))
				 r)
		 ))

;; ---- Lighter functions
(defun assistant/update-lighter () "Update the mode's lighter based on the status of the pending requests."
	   (interactive)
	   (if nil 
		   (if (> assistant/pending-responses 0)
			   ;; Pending requests
			   (setq minor-mode-alist
					 (cons '(assistant-mode
							 (:eval (concat (propertize assistant/lighter
														'face
														`(:background ,assistant/lighter-busy-color :weight bold))
											)
									))
						   (assq-delete-all 'assistant-mode minor-mode-alist)))
			 ;; Ready
			 (setq minor-mode-alist
				   (cons '(assistant-mode
						   (:eval (concat (propertize assistant/lighter
													  'face
													  `(:background ,assistant/lighter-ready-color :weight normal))
										  )
								  ))
						 (assq-delete-all 'assistant-mode minor-mode-alist))))))

;; ---- Chat buffer and window functions
(defun assistant/--build-buffer () "Function to build the chat buffer."
	   (setq assistant/$buffer (get-buffer-create assistant/buffer-name))
	   (with-current-buffer assistant/$buffer
		 (rename-buffer assistant/buffer-name)
		 ;; (if (commandp 'linum-mode) (linum-mode 0) (line-number-mode 0))
		 (cond
		  ((fboundp 'display-line-numbers-mode) (display-line-numbers-mode 0))
		  ((fboundp 'linum-mode) (linum-mode 0)))
		 (markdown-mode)
		 (toggle-truncate-lines 0))
	   assistant/$buffer)

(defun assistant/--refresh-chat-buffer ( &optional date messages-before) "Function to refresh the contents of the chat buffer."
	   (if (not assistant/active-chat) (setq assistant/active-chat (nth 1 (assistant/--db-get-last-chat))))
	   (unless messages-before (setq messages-before 20))
	   (unless date (setq date (current-time))) 
	   (assistant/--db-load-chat-history assistant/active-chat date messages-before))

(defun assistant/split-window () "Function to split frame if there is no second window."
	   (interactive)
	   (let ((otherwindow nil)
			 (currentwindow nil)
			 (lastchat (assistant/--db-get-last-chat))
			 (maxpos 0))
		 ;; 
		 
		 (if (one-window-p)
			 (if (string= assistant/split-direction "vertical")
				 (split-window-right))
		   (split-window-below))

		 (if (not (get-buffer assistant/buffer-name)) (progn
														(assistant/--build-buffer)
														(if lastchat (assistant/--db-load-chat-history lastchat))
														))
		 (setq currentwindow (selected-window)
			   otherwindow (window-next-sibling))
		 (set-window-buffer otherwindow assistant/$buffer)

		 ))

(defun assistant/ask-chat () "Interactive function to ask on chat window."
	   (interactive)

	   ;; If there is no chat buffer, build it.
	   (if (not assistant/$buffer) (assistant/--build-buffer))

	   ;; If there is no active chat, select one.
	   (if (not assistant/active-chat) (setq assistant/active-chat (nth 1 (assistant/--db-get-last-chat))))

	   ;; If there is no active model, select one.
	   (if (not assistant/active-chat-model) (setq assistant/active-chat-model (assistant/--db-get-last-model)))

	   ;; If is the first time a model is used, select the first one.
	   (if (and (not assistant/active-chat-model) (> (length assistant/models-list) 0))
					  (setq assistant/active-chat-model (plist-get (nth 0 assistant/models-list) :model)))

	   (let* ((dt (current-time))
			 (userinput (read-string (concat assistant/active-chat " (" assistant/active-chat-model "): "))))
		 (assistant/--db-save-message-to-db assistant/active-chat "user" userinput dt)
		 (assistant/add-chat-message "user" dt userinput)

		 ;; Send the query
		 (assistant/--request-chat assistant/with-current-api-n assistant/active-chat userinput)
		 ))

(defun assistant/toggle-chat-buffer () "Interactive function to toggle the chat buffer."
	   (interactive)
	   (unless (buffer-live-p assistant/$buffer) (assistant/--build-buffer))
	   (let ((is-visible (get-buffer-window assistant/$buffer)))
		 (if is-visible
			 (jump-to-register assistant/window-register)
		   (progn
			 (window-configuration-to-register assistant/window-register)
			 (delete-other-windows)
			 (split-window-horizontally)
			 (switch-to-buffer-other-window assistant/$buffer)
			 ))))

(defun assistant/set-window-size ( w ) "Interactive function to set the size of the window."
	   (interactive
		(list
		 (if current-prefix-arg
			 (prefix-numeric-value current-prefix-arg)
		   (read-number "Give the width of the window: "))))

	   (setq assistant/window-size w)
	   (customize-save-variable 'assistant/window-size w))

;; ---- Rest
(defun assistant/--request-chat ( api chat message ) "Function to make API requests for chat."
	   (let* ((sbdata (nth api assistant/api-subscriptions))
			  (provider (nth 0 sbdata))
			  (apitype (nth 1 sbdata))
			  (protocol (nth 2 sbdata))
			  (hostname (nth 3 sbdata))
			  (port (nth 4 sbdata))
			  (chaturl (nth 6 sbdata))
			  (apikey (nth 9 sbdata))
			  (chatinfo (assistant/--db-get-chat-info chat)))

		 (setq assistant/pending-responses (1+ assistant/pending-responses))
		 (assistant/update-lighter)

		 (funcall (intern (concat "assistant/--request-chat-" apitype))
				  chatinfo
				  message
				  provider
				  protocol
				  hostname
				  port
				  chaturl
				  apikey
				  (lambda (&key data &rest _) "Success Function"
					(let* ((apitype (nth 1 assistant/with-current-api))
						   (dt (current-time))
						   (chatinfo (assistant/--db-get-chat-info assistant/active-chat))
						   (model (plist-get chatinfo :model))
						   (fdata (funcall (intern (concat "assistant/--chat-response-" apitype)) (json-parse-string data))))
					  (assistant/--db-save-message-to-db assistant/active-chat model fdata dt)
					  (assistant/add-chat-message (concat "assistant:" model) dt fdata)))
				  (lambda (&key error-thrown &rest _) "Error function"
					(error "ERROR: %S" error-thrown))
				  (lambda (&rest _) "Complete Function"
					(setq assistant/pending-responses (1- assistant/pending-responses))
					(assistant/update-lighter))
				  )))

(defun assistant/build-code () "Build code."
		   (interactive)
		   (message "Code")
		   )

(defun assistant/--scroll-buffer-to-bottom () "Function to scroll the chat window to the bottom of chat buffer."
	   (with-current-buffer assistant/$buffer
		 (point (point-max))))

;; Load the plugins
(setq assistant/load-path (file-name-as-directory (directory-file-name (file-name-directory (or load-file-name buffer-file-name)))))
(setq assistant/load-ollama t)
(setq assistant/load-openwebui nil)
(setq assistant/load-lmstudio nil)
(if (and assistant/load-ollama (file-exists-p (concat assistant/load-path "assistant-ollama.el")))
	(progn
	  ;; (require 'assistant-ollama)
	  (load (concat assistant/load-path "assistant-ollama.el"))))
(if (and assistant/load-openwebui (file-exists-p (concat assistant/load-path "assistant-openwebui.el")))
	(progn
	  ;; (require 'assistant-openwebui)
	  (load (concat assistant/load-path "assistant-openwebui.el"))))
(if assistant/load-lmstudio (progn
							  ;; (require 'assistant-lmstudio)
							  (if (file-exists-p (concat assistant/load-path "assistant-lmstudio-openai.v1.el"))
								  (load (concat assistant/load-path "assistant-lmstudio-openai-v1.el")))
							  (if (file-exists-p (concat assistant/load-path "assistant-lmstudio-v0.el"))
								  (load (concat assistant/load-path "assistant-lmstudio-v0.el")))
							  (if (file-exists-p (concat assistant/load-path "assistant-lmstudio-v1.el"))
								  (load (concat assistant/load-path "assistant-lmstudio-v1.el")))
							  ))

;;---- MINOR MODE ------------------------------------------------------------------
;;;###autoload
(define-minor-mode assistant-mode "Assistant minor mode."
  :lighter assistant/--lighter
  :global 1
  :keymap (let ((assistantmap (make-sparse-keymap)))
			(require 'request)
			(require 'json)

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
				  (assistant/--db-build-db))

			  ;; If database file exists, open it.
			  (setq assistant/db-history (sqlite-open (concat assistant/history-path "/db.sqlite3"))))

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Build models list
			(if (not assistant/models-list)
				(progn
				  (assistant/update-all-apis)
				  (setq assistant/active-chat-model assistant/default-chat-model)
				  (if (and (not assistant/active-chat-model) (> (length assistant/models-list) 0))
					  (setq assistant/active-chat-model (plist (nth 0 assistant/models-list) :model)))))

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; BUILD BUFFER
			(assistant/--build-buffer)
			(assistant/--refresh-chat-buffer)

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Update APIs
			(assistant/update-all-apis)

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Build Lighter menu
			(define-key-after		 ; Menu for Assistant mode
			  assistant/assistant-keymap
			  [menu-bar assistantmenu]
			  (cons "Assistant" (make-sparse-keymap "assinstant mode"))
			  'kill-buffer)

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuaskchatbot]
						'("Chat" . assistant/ask-chat))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuaskcodebot]
						'("Build code" . assistant/build-code))


			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenusep01] '("--"))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenunewchat]
						'("New chat" . assistant/new-chat))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchangechat]
						'("Change chat" . assistant/select-chat))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenusep02] '("--"))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchangechatmodel]
						'("Change chat model" . assistant/select-chat-model))

			(define-key assistant/assistant-keymap [menu-bar assistantmenu assistantmenuchangecodemodel]
						'("Change code model" . assistant/change-code-model))

			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
			;; Keyboard shortcuts

			(define-key assistant/assistant-keymap (kbd assistant/assistant-activate-chat-keycomb) 'assistant/ask-chat)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-select-chat) 'assistant/select-chat)

			;; (define-key assistant/assistant-keymap (kbd assistant/assistant-continue-code-keycomb) 'assistant/build-code)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-set-window-size-keycomb) 'assistant/set-window-size)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-select-chat-model-keycomb) 'assistant/select-chat-model)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-change-code-model-keycomb) 'assistant/change-code-model)

			(define-key assistant/assistant-keymap (kbd assistant/assistant-toggle-buffer-keycomb) 'assistant/toggle-chat-buffer)

			assistant/assistant-keymap))

;;;###autoload
(assistant-mode 1)

(provide 'assistant-mode)
