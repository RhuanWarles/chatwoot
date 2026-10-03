json.extract! deal, :id, :name, :value, :status
json.pipeline do
  json.extract! deal.pipeline, :id, :name
end
json.pipeline_stage do
  json.extract! deal.pipeline_stage, :id, :name
end
json.contact do
  if deal.contact
    json.extract! deal.contact, :id, :name, :phone_number, :email
    json.company_name deal.contact.company&.name || deal.contact.additional_attributes['company_name']
  end
end
