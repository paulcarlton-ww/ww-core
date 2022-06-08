import urllib3
import json
import yaml

http = urllib3.PoolManager()
def lambda_handler(event, context):
    
    #In this implementation, payload.summary is set to description (to mimic pagerduty_config.description)
    #In this implementation, payload.source is set to client_url
    
    url = "https://events.eu.pagerduty.com/v2/enqueue"
    msg = yaml.safe_load(event['Records'][0]['Sns']['Message'])
    details = None
    links = None 
    summary = None
    client_url = None
    severity = None
    
    ############################################################
    #Remove elements
    if 'description' in msg.keys():
        summary = msg['description']
        msg.pop('description')
    
    if 'client_url' in msg.keys():
        client_url = msg['client_url']
        msg.pop('client_url')
    
    if 'severity' in msg.keys():
        severity = msg['severity']
        msg.pop('severity')
    
    if 'details' in msg.keys():
        details = msg['details']
        msg['details'] = ""
        msg.pop('details')
        
    if 'links' in msg.keys():
        links = msg['links']
        msg['links'] = ""
        msg.pop('links')

    ############################################################
    
    #Add event_action back in 
    if event['Records'][0]['Sns']['Subject'].find('[RESOLVED]') > -1:
        msg.update({"event_action":"resolve"})
    else:
        msg.update({"event_action":"trigger"})
    
    #Add payload fields back in
    payload = { "payload": { "client_url": client_url, "severity": severity, "summary": summary, "source": client_url } }
    msg.update(payload)
    
    #Add details fields
    if details is not None and len(details) > 0:
        details = { "custom_details": details } 
        msg["payload"].update(details)
    
    #Add links fields
    if links is not None and len(links) > 0:
        msg["links"] = links

    encoded_msg = json.dumps(msg).encode('utf-8')
    resp = http.request('POST',url, body=encoded_msg)
    print({
        "SNS": event['Records'][0]['Sns'],
        "message": event['Records'][0]['Sns']['Message'], 
        "status_code": resp.status, 
        "response": resp.data
    })


