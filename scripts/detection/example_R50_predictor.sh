cd "$(dirname "$0")"
set -e

cd ../../

name=R50_R480_FLOPs188e8_predictor
work_dir=save_model/LightNAS/detection/${name}

mkdir -p ${work_dir}
space_mutation="space_K1KXK1"
cp nas/spaces/${space_mutation}.py ${work_dir}
cp scripts/detection/example_R50_predictor.sh ${work_dir}

echo "[\
{'class': 'ConvKXBNRELU', 'in': 3, 'out': 32, 's': 2, 'k': 3}, \
{'class': 'SuperResConvK1KXK1', 'in': 32, 'out': 256, 's': 2, 'k': 3, 'L': 1, 'btn': 64}, \
{'class': 'SuperResConvK1KXK1', 'in': 256, 'out': 512, 's': 2, 'k': 3, 'L': 1, 'btn': 128}, \
{'class': 'SuperResConvK1KXK1', 'in': 512, 'out': 768, 's': 2, 'k': 3, 'L': 1, 'btn': 256}, \
{'class': 'SuperResConvK1KXK1', 'in': 768, 'out': 1024, 's': 1, 'k': 3, 'L': 1, 'btn': 256}, \
{'class': 'SuperResConvK1KXK1', 'in': 1024, 'out': 2048, 's': 2, 'k': 3, 'L': 1, 'btn': 512}, \
]" \
  >${work_dir}/init_structure.txt

rm -rf acquired_gpu_list.*
mpirun --allow-run-as-root -np 8 -H 127.0.0.1:8 -bind-to none -map-by slot -mca pml ob1 \
  -mca btl ^openib -x NCCL_DEBUG=INFO -x LD_LIBRARY_PATH -x PATH \
  python nas/search.py configs/config_nas.py --work_dir ${work_dir} \
  --cfg_options task="detection" space_classfication=False only_master=False log_level="INFO" \
  budget_image_size=480 budget_flops=188e8 budget_latency=8e-4 budget_layers=91 budget_model_size=None \
  score_type="entropy" score_batch_size=32 score_image_size=480 score_repeat=4 score_multi_ratio=[0,0,1,1,6] \
  lat_gpu=False lat_pred=True lat_date_type="FP16" lat_pred_device="V100" lat_batch_size=32 \
  space_arch="MasterNet" space_mutation=${space_mutation} space_structure_txt=${work_dir}/init_structure.txt
