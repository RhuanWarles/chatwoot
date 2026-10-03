json.payload do
  json.deals do
    json.array! @result[:deals] do |deal|
      json.partial! 'deal', formats: [:json], deal: deal
    end
  end
end
