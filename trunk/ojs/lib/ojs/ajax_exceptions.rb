class NotAuthorized < StandardError
  def http_status
    403
  end
  def formatted_message
    message
  end
end

class ActiveRecord::RecordInvalid
  def http_status
    422
  end
  def json_messages
    errs = []
    record.errors.each do |attr, msg|
      msg = if attr == "base" then msg else record.class.human_attribute_name(attr) + " " + msg end
      errs << {:message=>msg, :on=>attr}
    end
    errs.to_json
  end
  def formatted_message
    message
  end
end

class Exception
  def http_status
    500
  end
  def json_messages
    [{:message=>formatted_message,:on=>'base'}].to_json
  end
  def formatted_message
    "<b>Server Error:</b> #{message} (#{self.class.name})"
  end
end

class ActiveRecord::RecordNotFound
  def http_status
    404
  end
end