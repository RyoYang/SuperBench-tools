import json
import datetime
from azure.kusto.data import KustoConnectionStringBuilder, KustoClient
from azure.kusto.ingest.status import KustoIngestStatusQueues
from azure.kusto.data.helpers import dataframe_from_result_table
import time
import pprint
from azure.kusto.ingest import (
    QueuedIngestClient,
    IngestionProperties,
    ReportLevel,
)
try:
    from azure.kusto.ingest import DataFormat
except ImportError:
    from azure.kusto.data.data_format import DataFormat

import pandas
from pandas.core.frame import DataFrame

AUTHORITY_ID = "72f988bf-86f1-41af-91ab-2d7cd011db47" # tenant id
SECRET_ID = "P4v8Q~emeLzgMYtfHKfAe1vlSpJwGXsXD_P9Pdxe" # secret id
CLIENT_ID = "5891995b-aa75-4342-849b-7d9382fcbbd5" # app id from app registration

KUSTO_URI = "https://sbibvalidation.centralus.kusto.windows.net/"
KUSTO_INGEST_URI = "https://ingest-sbibvalidation.centralus.kusto.windows.net/"

KUSTO_DATABASE = "ibvalidationresult"
KUSTO_TABLE = "ibvalidationresult"

table_schema = {
    "type": "Record",
    "fields": [
        {"name": "timestamp", "type": "Timestamp"},
        {"name": "user_id", "type": "Int64"},
        {"name": "page_views", "type": "Int64"}
    ]
}

def ingestion_status(client: QueuedIngestClient) -> None:
    """
    This method gives the data ingestion status.
    """
    qs = KustoIngestStatusQueues(client)
    MAX_BACKOFF = 180

    backoff = 1
    while True:
        if qs.success.is_empty() and qs.failure.is_empty():
            time.sleep(backoff)
            if backoff>=180:
                break
            backoff = min(backoff * 2, MAX_BACKOFF)
            print("No new messages. backing off for {} seconds".format(backoff))
            if(backoff >= 30):
                print("No new messages. backing off for {} seconds, stop!".format(backoff))
                break
            continue
        else:
            break

    backoff = 1

    success_messages = qs.success.pop(10)
    failure_messages = qs.failure.pop(10)

    pprint.pprint("SUCCESS : {}".format(success_messages))
    pprint.pprint("FAILURE : {}".format(failure_messages))


def ingest_to_kusto(dataframe_to_ingest: DataFrame, table_name: str) -> None:
    """
    This method ingests data to the given kusto table in SingleNodeResults DB.
    """

    kcsb = KustoConnectionStringBuilder.with_aad_application_key_authentication(KUSTO_INGEST_URI, CLIENT_ID, SECRET_ID, AUTHORITY_ID)

    client = QueuedIngestClient(kcsb)
    ingestion_props = IngestionProperties(
        database=KUSTO_DATABASE,
        table=table_name,
        data_format=DataFormat.CSV,
        report_level=ReportLevel.FailuresAndSuccesses
    )

    client.ingest_from_dataframe(dataframe_to_ingest, ingestion_properties=ingestion_props)
    # ingestion_status(client)

import json

with open('results-summary.jsonl', 'r') as json_file:
    json_list = list(json_file)

# kcsb = KustoConnectionStringBuilder.with_aad_application_key_authentication(KUSTO_INGEST_URI, CLIENT_ID, SECRET_ID, AUTHORITY_ID)
# dataframe_from_result_table(RESPONSE.primary_results[0])


for json_str in json_list:
    create_table_string = ".create table {} ".format(KUSTO_TABLE)

    result = json.loads(json_str)
    # print(f"result: {result}")
    # print(f"result['node']: {result['node']}")
    # if 'nccl-bw:ib/allreduce_1073741824_algbw' in result:
    #     print(f"result['nccl-bw:ib/allreduce_1073741824_algbw']: {result['nccl-bw:ib/allreduce_1073741824_algbw']}")

    fields = []
    values = []
    types = []
    node = result["node"]
    for field, value in result.items():
        if "algbw" in field:
            fields.append(field.replace(":", "_").replace("/", '_').replace("-", '_'))
            values.append(value)
            types.append("string" if type(value) == str else "real")


    
    if fields and values:
        # Insert timestamp
        fields.insert(0, "PreciseTimeStamp")
        precise_time_stamp = str(datetime.datetime.now())
        values.insert(0, precise_time_stamp)
        types.insert(0, "datetime")
        
        # Insert node
        fields.insert(1, "node")
        values.insert(1, node)
        types.insert(1, "string")        

    df = pandas.DataFrame(data=[values], columns=fields)
    
    create_table_string = create_table_string + "(" + ", ".join([f"{field}:{type}" for field, type in zip(fields, types)]) + ")"
    if "algbw" in create_table_string:
        print(fields)
        print(create_table_string)
    ingest_to_kusto(df, KUSTO_TABLE)
        
    
        # ingest_to_kusto(df, KUSTO_TABLE)
    # print("{}['nccl-bw:ib/allreduce_1073741824_algbw']: {}".format(result['node'], result['nccl-bw:ib/allreduce_1073741824_algbw']))
    