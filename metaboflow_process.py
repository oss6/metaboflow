import zipfile
import dimspy.tools as ts
import os
import shutil
import json
import numpy
import sys
import process_scans

def process_samples(config_filename):
    workflow_config_fd = open(config_filename)
    workflow_config = json.load(workflow_config_fd)
    workflow_config_fd.close()

    data_path = workflow_config.get('data_path')
    filelist_filename = workflow_config.get('filelist_path')
    output_directory = workflow_config.get('output_directory')
    scans_path = workflow_config.get('scans_path')
    use_scans_path = workflow_config.get('use_scans_path', False)
    use_galaxy = workflow_config.get('use_galaxy', False)

    if os.path.isdir(output_directory):
        shutil.rmtree(output_directory)
    os.mkdir(output_directory)

    print('Process scans...')

    if use_scans_path and os.path.exists(scans_path):
        scans = ts.hdf5_portal.load_peaklists_from_hdf5(scans_path)
    else:
        data_directory = data_path

        if use_galaxy:
            scans_path = process_scans.galaxy_process_scans(workflow_config)
            scans = ts.hdf5_portal.load_peaklists_from_hdf5('scans_tmp.h5')
        else:
            if zipfile.is_zipfile(data_path):
                with zipfile.ZipFile(data_path, 'r') as zip_ref:
                    data_directory = 'data'
                    zip_ref.extractall(data_directory)

            process_scans_opt = workflow_config['process_scans']
            scans = ts.process_scans(
                data_directory,
                function_noise=process_scans_opt['function_noise'],
                snr_thres=process_scans_opt['snr_thres'],
                ppm=process_scans_opt['ppm'],
                min_fraction=process_scans_opt['min_fraction'],
                min_scans=process_scans_opt['min_scans'],
                filelist=filelist_filename)

            if scans_path is not None:
                ts.hdf5_portal.save_peaklists_as_hdf5(scans, scans_path)

    print('Applying replicate filter...')
    replicate_filter_opt = workflow_config['replicate_filter']
    filtered_scans = ts.replicate_filter(
        scans,
        replicates=replicate_filter_opt['replicates'],
        min_peaks=replicate_filter_opt['min_peaks'],
        ppm=replicate_filter_opt['ppm'],
        rsd_thres=replicate_filter_opt['rsd_thres'],
        report=os.path.join(output_directory, 'processing_report.tsv'))
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

    numpy.savetxt(os.path.join(output_directory, 'rsd.tsv'), peak_matrix_filtered.rsd(classLabel = 'QC'), delimiter = '\t')

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
