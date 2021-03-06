import os
from bioblend.galaxy import GalaxyInstance
from bioblend.galaxy.histories import HistoryClient
from bioblend.galaxy.tools import ToolClient
from bioblend.galaxy.datasets import DatasetClient
from bioblend.galaxy.workflows import WorkflowClient
from bioblend.galaxy.invocations import InvocationClient
from modules.processing import pim_processing

def run_workflow(workflow_config):
    galaxy_opts = workflow_config.get('galaxy')
    data_filename = workflow_config.get('data_path')
    filelist_filename = workflow_config.get('filelist_path')
    output_directory = workflow_config.get('output_directory')

    galaxy_instance = GalaxyInstance(
        url='https://metabolomics-training.galaxy.bham.ac.uk',
        key=galaxy_opts.get('api_key')
    )
    history_client = HistoryClient(galaxy_instance)
    tool_client = ToolClient(galaxy_instance)
    dataset_client = DatasetClient(galaxy_instance)
    workflow_client = WorkflowClient(galaxy_instance)
    invocation_client = InvocationClient(galaxy_instance)

    history = history_client.create_history(galaxy_opts.get('history_name', 'Process metabolomics data'))

    print('Created history with ID: ' + history['id'])

    print('Uploading datasets...')
    tool_client.upload_file(data_filename, history['id'], file_type='zip')
    tool_client.upload_file(filelist_filename, history['id'], file_type='tsv')

    datasets = dataset_client.get_datasets(history_id=history.get('id'))
    batch_dataset = next(d for d in datasets if d.get('name') == os.path.basename(data_filename))
    filelist_dataset = next(d for d in datasets if d.get('name') == os.path.basename('filelist_batch_06.txt'))

    print('Waiting for datasets to be in terminal state...')
    dataset_client.wait_for_dataset(datasets[0].get('id'))
    dataset_client.wait_for_dataset(datasets[1].get('id'))

    w_inputs = {
        '0': {'id': batch_dataset.get('id'), 'src': 'hda'},
        '1': {'id': filelist_dataset.get('id'), 'src': 'hda'}
    }

    process_scans_opt = workflow_config.get('process_scans')
    replicate_filter_opt = workflow_config.get('replicate_filter')
    align_samples_opt = workflow_config.get('align_samples')
    blank_filter_opt = workflow_config.get('blank_filter')
    sample_filter_opt = workflow_config.get('sample_filter')

    w_params = {
        '2': {
            'function_noise': process_scans_opt.get('function_noise'),
            'snr_threshold': process_scans_opt.get('snr_thres'),
            'mults|ppm': process_scans_opt.get('ppm'),
            'mults|min_fraction': process_scans_opt.get('min_fraction'),
            'mults|min_scans': process_scans_opt.get('min_scans')
        },
        '3': {
            'replicates': replicate_filter_opt.get('replicates'),
            'min_peaks': replicate_filter_opt.get('min_peaks'),
            'ppm': replicate_filter_opt.get('ppm'),
            'rsd_threshold': replicate_filter_opt.get('rsd_thres', '')
        },
        '4': {
            'ppm': align_samples_opt.get('ppm')
        },
        '5': {
            'min_fold_change': blank_filter_opt.get('min_fold_change'),
            'min_fraction': blank_filter_opt.get('min_fraction'),
            'blank_label': blank_filter_opt.get('label'),
            'function': blank_filter_opt.get('function')
        },
        '6': {
            'min_fraction': sample_filter_opt.get('min_fraction')
        }
    }

    print('Waiting for workflow to finish...')
    workflow = workflow_client.get_workflows(name = 'Metabolomics workflow')[0]
    invocation = workflow_client.invoke_workflow(
        workflow.get('id'),
        history_id=history.get('id'),
        import_inputs_to_history=True,
        inputs=w_inputs,
        params=w_params
    )

    invocation_client.wait_for_invocation(invocation.get('id'))

    # Download datasets
    tsv_datasets = dataset_client.get_datasets(history_id=history.get('id'), extension='tsv')
    peak_intensity_matrix_dataset = next(d for d in tsv_datasets if d.get('name').lower().endswith('peak intensity matrix'))
    peak_intensity_matrix_comprehensive_dataset = next(d for d in tsv_datasets if d.get('name').lower().endswith('peak intensity matrix (comprehensive)'))
    sample_meta_dataset = next(d for d in tsv_datasets if 'blank filter' in d.get('name').lower() and 'sample metadata' in d.get('name').lower())

    dataset_client.download_dataset(
        peak_intensity_matrix_dataset.get('id'),
        os.path.join(output_directory, 'peak-intensity-matrix.tsv'),
        use_default_filename=False
    )
    dataset_client.download_dataset(
        peak_intensity_matrix_comprehensive_dataset.get('id'),
        os.path.join(output_directory, 'peak-intensity-matrix_comprehensive.tsv'),
        use_default_filename=False
    )
    dataset_client.download_dataset(
        sample_meta_dataset.get('id'),
        os.path.join(output_directory, 'peak-intensity-matrix_meta.tsv'),
        use_default_filename=False
    )

    # Save RSD file
    pim_processing.save_rsd(workflow_config, os.path.join(output_directory, 'peak-intensity-matrix_comprehensive.tsv'))
