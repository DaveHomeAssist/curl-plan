.PHONY: feature-review account-backend-verify

feature-review:
	@if [ -n "$(CHANGED_FILES)" ]; then \
		scripts/feature_review_matrix_check.sh $(CHANGED_FILES); \
	else \
		scripts/feature_review_matrix_check.sh; \
	fi

account-backend-verify:
	node scripts/verify-account-backend.mjs
