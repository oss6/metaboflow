import zipfile
import dimspy.tools as ts
import os
import shutil
import json

def process_samples(config_filename):
    workflow_config_fd = open(config_filename)
    workflow_config = json.load(workflow_config_fd)
    workflow_config_fd.close()

    batch_zip_filename = 'examples/batch_06.zip'
    data_directory = workflow_config['data_path']
    filelist_filename = workflow_config['filelist_path']
    output_directory = workflow_config['output_directory']
    scans_path = workflow_config['scans_path']

    if os.path.isdir(output_directory):
        shutil.rmtree(output_directory)
    os.mkdir(output_directory)

    print('Process scans...')

    if os.path.exists(scans_path):
        scans = ts.hdf5_portal.load_peaklists_from_hdf5(scans_path)
    else:
        # with zipfile.ZipFile(batch_zip_filename, 'r') as zip_ref:
        #     zip_ref.extractall(data_directory)
        scans = ts.process_scans(
            data_directory,
            function_noise='median',
            snr_thres=3.0,
            filelist=filelist_filename,
            ppm=2.0)
        
        ts.hdf5_portal.save_peaklists_as_hdf5(scans, scans_path)
    
    print('Applying replicate filter...')
    replicate_filter_opt = workflow_config['replicate_filter']
    filtered_scans = ts.replicate_filter(
        scans,
        replicates=replicate_filter_opt['replicates'],
        min_peaks=replicate_filter_opt['min_peaks'],
        ppm=replicate_filter_opt['ppm'],
        rsd_thres=replicate_filter_opt['rsd_thres'])
    ts.create_sample_list(filtered_scans, os.path.join(output_directory, 'meta_filtered-scans.tsv'))

    print('Aligning samples...')
    align_samples_opt = workflow_config['align_samples']
    peak_matrix = ts.align_samples(
        filtered_scans,
        ppm=align_samples_opt['ppm'],
        filelist=os.path.join(output_directory, 'meta_filtered-scans.tsv'))

    print('Applying blank filter...')
    blank_filter_opt = workflow_config['blank_filter']
    peak_matrix_blank_filtered = ts.blank_filter(
        peak_matrix,
        blank_label=blank_filter_opt['label'],
        min_fold_change=blank_filter_opt['min_fold_change'],
        min_fraction=blank_filter_opt['min_fraction'],
        function=blank_filter_opt['function'])
    ts.create_sample_list(peak_matrix_blank_filtered, os.path.join(output_directory, 'meta_blank-filtered.tsv'))

    print('Applying sample filter...')
    sample_filter_opt = workflow_config['sample_filter']
    peak_matrix_filtered = ts.sample_filter(
        peak_matrix_blank_filtered,
        min_fraction=sample_filter_opt['min_fraction'])

    ts.hdf5_portal.save_peak_matrix_as_hdf5(
        peak_matrix_filtered,
        os.path.join(output_directory, 'peak-intensity-matrix.hdf5'))
    ts.hdf5_peak_matrix_to_txt(
        os.path.join(output_directory, 'peak-intensity-matrix.hdf5'),
        os.path.join(output_directory, 'peak-intensity-matrix.tsv'))
    ts.hdf5_peak_matrix_to_txt(
        os.path.join(output_directory, 'peak-intensity-matrix.hdf5'),
        os.path.join(output_directory, 'peak-intensity-matrix-comprehensive.tsv'),
        comprehensive=True)
