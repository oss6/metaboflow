from bioblend.galaxy import GalaxyInstance
from bioblend.galaxy.histories import HistoryClient
from bioblend.galaxy.tools import ToolClient
from bioblend.galaxy.tools.inputs import inputs, dataset, conditional
from bioblend.galaxy.datasets import DatasetClient
from bioblend.galaxy.jobs import JobsClient

def galaxy_process_scans(workflow_config):
    galaxy_instance = GalaxyInstance(url='https://metabolomics-training.galaxy.bham.ac.uk', key=workflow_config.get('galaxy_api_key'))
    history_client = HistoryClient(galaxy_instance)
    tool_client = ToolClient(galaxy_instance)
    dataset_client = DatasetClient(galaxy_instance)
    jobs_client = JobsClient(galaxy_instance)

    data_filename = workflow_config.get('data_path')
    filelist_filename = workflow_config.get('filelist_path')

    history = history_client.create_history('Process DIMS Scans')

    print('Created history with ID: ' + history['id'])

    print('Uploading datasets...')
    tool_client.upload_file(data_filename, history['id'], file_type='zip')
    tool_client.upload_file(filelist_filename, history['id'], file_type='tsv')

    datasets = dataset_client.get_datasets(history_id=history.get('id'))
    batch_dataset = next(d for d in datasets if d.get('name') == 'batch_06.zip')
    filelist_dataset = next(d for d in datasets if d.get('name') == 'filelist_batch_06.txt')

    print('Waiting for datasets to be in terminal state...')
    dataset_client.wait_for_dataset(datasets[0].get('id'))
    dataset_client.wait_for_dataset(datasets[1].get('id'))

    process_scans_opt = workflow_config.get('process_scans')
    tools_inputs = (
        inputs()
        .set('data', dataset(batch_dataset.get('id')))
        .set('filelist', dataset(filelist_dataset.get('id')))
        .set('function_noise', process_scans_opt.get('function_noise'))
        .set('snr_threshold', process_scans_opt.get('snr_thres'))
        .set(
            'mults',
            conditional()
                .set('ppm', process_scans_opt.get('ppm'))
                .set('min_fraction', process_scans_opt.get('min_fraction'))
                .set('min_scans', process_scans_opt.get('min_scans'))
        )
    )

    process_scans_result = tool_client.run_tool(
        history.get('id'),
        'toolshed.g2.bx.psu.edu/repos/computational-metabolomics/dimspy_process_scans/dimspy_process_scans/2.0.0+galaxy0',
        tool_inputs=tools_inputs,
        input_format='21.01')

    process_scans_job_id = process_scans_result.get('jobs')[0].get('id')

    print('Waiting for job to finish...')
    jobs_client.wait_for_job(process_scans_job_id)

    scans_dataset = dataset_client.get_datasets(history_id=history.get('id'), extension='h5')[0]
    dataset_client.download_dataset(scans_dataset.get('id'), 'scans_tmp.h5', use_default_filename=False)
