.PHONY: feature-review

feature-review:
	@if [ -n "$(CHANGED_FILES)" ]; then \
		scripts/feature_review_matrix_check.sh $(CHANGED_FILES); \
	else \
		scripts/feature_review_matrix_check.sh; \
	fi
