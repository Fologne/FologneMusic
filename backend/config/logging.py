import logging


class SafeRequestLog(logging.Filter):
    def filter(self, record):
        request = getattr(record, "request", None)
        match = getattr(request, "resolver_match", None)
        record.msg = "HTTP %s (%s)"
        record.args = (
            getattr(record, "status_code", "unknown"),
            getattr(match, "view_name", "unmatched"),
        )
        # Exception messages can contain the signed URL or user metadata.
        record.exc_info = None
        record.exc_text = None
        return True
