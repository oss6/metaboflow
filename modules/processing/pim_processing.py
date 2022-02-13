import os
import numpy
import dimspy.tools as ts

def save_rsd(workflow_config, pim):
    if isinstance(pim, str):
        pim = ts.txt_portal.load_peak_matrix_from_txt(pim)

    output_directory = workflow_config.get('output_directory')
    numpy.savetxt(os.path.join(output_directory, 'rsd.tsv'), pim.rsd(classLabel = workflow_config.get('qc_label')), delimiter = '\t')
    numpy.savetxt(os.path.join(output_directory, 'rsd_cow.tsv'), pim.rsd(classLabel = 'cow'), delimiter = '\t')
    numpy.savetxt(os.path.join(output_directory, 'rsd_sheep.tsv'), pim.rsd(classLabel = 'sheep'), delimiter = '\t')
