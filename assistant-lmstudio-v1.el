(defun assistant/-lmstudio-api-points () "Returns the available URL API points for LM-Studio."
	   (list "v1/completions"
			 "api/v1/chat"
			 "api/v1/models"
			 "v1/embeddings"))

(defun assistant/--get-list-of-models-lmstudio ( data ) "Analyze the LM-Studio API JSON and get the list of models."
	   (message "MODELS DATA:")
	   (message "%S" data)
	   )

(defun assistant/--request-chat-lmstudio ( chat message provider protocol hostname port chaturl apikey success-callback error-callback complete-callback) "Function for handling the request for the lmstudio api."
	   
	   )

(defun assistant/--request-models-list-lmstudio ( provider protocol hostname port path apikey ) "Function to get the list of models for the LM-Studio API."
	   )
