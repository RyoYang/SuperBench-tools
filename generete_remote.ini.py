import re

# The string to search
string1 = """
yangwang1-vmss_117
yangwang1-000039
Running
Succeeded
No
yangwang1-vmss_118
yangwang1-00003A
Running
Succeeded
Yes
yangwang1-vmss_119
yangwang1-00003B
Running
Succeeded
No
yangwang1-vmss_120
yangwang1-00003C
Running
Succeeded
No
yangwang1-vmss_122
yangwang1-00003E
Running
Succeeded
Yes
yangwang1-vmss_124
yangwang1-00003G
Running
Succeeded
Yes
yangwang1-vmss_125
yangwang1-00003H
Running
Succeeded
Yes
yangwang1-vmss_126
yangwang1-00003I
Running
Succeeded
Yes
yangwang1-vmss_128
yangwang1-00003K
Running
Succeeded
Yes
yangwang1-vmss_129
yangwang1-00003L
Running
Succeeded
Yes
yangwang1-vmss_130
yangwang1-00003M
Running
Succeeded
Yes
yangwang1-vmss_131
yangwang1-00003N
Running
Succeeded
Yes
yangwang1-vmss_132
yangwang1-00003O
Running
Succeeded
Yes
yangwang1-vmss_133
yangwang1-00003P
Running
Succeeded
Yes
yangwang1-vmss_134
yangwang1-00003Q
Running
Succeeded
Yes
yangwang1-vmss_135
yangwang1-00003R
Running
Succeeded
Yes
yangwang1-vmss_136
yangwang1-00003S
Running
Succeeded
Yes
yangwang1-vmss_137
yangwang1-00003T
Running
Succeeded
Yes
yangwang1-vmss_139
yangwang1-00003V
Running
Succeeded
Yes
yangwang1-vmss_140
yangwang1-00003W
Running
Succeeded
Yes
yangwang1-vmss_141
yangwang1-00003X
Running
Succeeded
Yes
yangwang1-vmss_142
yangwang1-00003Y
Running
Succeeded
Yes
yangwang1-vmss_143
yangwang1-00003Z
Running
Succeeded
Yes
yangwang1-vmss_145
yangwang1-000041
Running
Succeeded
Yes
yangwang1-vmss_147
yangwang1-000043
Running
Succeeded
Yes
yangwang1-vmss_148
yangwang1-000044
Running
Succeeded
Yes
yangwang1-vmss_149
yangwang1-000045
Running
Succeeded
Yes
yangwang1-vmss_150
yangwang1-000046
Running
Succeeded
Yes
yangwang1-vmss_151
yangwang1-000047
Running
Succeeded
Yes
yangwang1-vmss_152
yangwang1-000048
Running
Succeeded
Yes
yangwang1-vmss_153
yangwang1-000049
Running
Succeeded
Yes
yangwang1-vmss_154
yangwang1-00004A
Running
Succeeded
Yes
"""


string2 = """
yangwang1-vmssLBNatPool.117
20.107.14.6
50000
yangwang1-vmss (instance 117)
SSH (TCP/22)
yangwang1-vmssLBNatPool.118
20.107.14.6
50001
yangwang1-vmss (instance 118)
SSH (TCP/22)
yangwang1-vmssLBNatPool.119
20.107.14.6
50002
yangwang1-vmss (instance 119)
SSH (TCP/22)
yangwang1-vmssLBNatPool.120
20.107.14.6
50003
yangwang1-vmss (instance 120)
SSH (TCP/22)
yangwang1-vmssLBNatPool.122
20.107.14.6
50004
yangwang1-vmss (instance 122)
SSH (TCP/22)
yangwang1-vmssLBNatPool.124
20.107.14.6
50006
yangwang1-vmss (instance 124)
SSH (TCP/22)
yangwang1-vmssLBNatPool.125
20.107.14.6
50007
yangwang1-vmss (instance 125)
SSH (TCP/22)
yangwang1-vmssLBNatPool.126
20.107.14.6
50008
yangwang1-vmss (instance 126)
SSH (TCP/22)
yangwang1-vmssLBNatPool.128
20.107.14.6
50010
yangwang1-vmss (instance 128)
SSH (TCP/22)
yangwang1-vmssLBNatPool.129
20.107.14.6
50011
yangwang1-vmss (instance 129)
SSH (TCP/22)
yangwang1-vmssLBNatPool.130
20.107.14.6
50012
yangwang1-vmss (instance 130)
SSH (TCP/22)
yangwang1-vmssLBNatPool.131
20.107.14.6
50013
yangwang1-vmss (instance 131)
SSH (TCP/22)
yangwang1-vmssLBNatPool.132
20.107.14.6
50014
yangwang1-vmss (instance 132)
SSH (TCP/22)
yangwang1-vmssLBNatPool.133
20.107.14.6
50015
yangwang1-vmss (instance 133)
SSH (TCP/22)
yangwang1-vmssLBNatPool.134
20.107.14.6
50016
yangwang1-vmss (instance 134)
SSH (TCP/22)
yangwang1-vmssLBNatPool.135
20.107.14.6
50017
yangwang1-vmss (instance 135)
SSH (TCP/22)
yangwang1-vmssLBNatPool.136
20.107.14.6
50018
yangwang1-vmss (instance 136)
SSH (TCP/22)
yangwang1-vmssLBNatPool.137
20.107.14.6
50019
yangwang1-vmss (instance 137)
SSH (TCP/22)
yangwang1-vmssLBNatPool.139
20.107.14.6
50021
yangwang1-vmss (instance 139)
SSH (TCP/22)
yangwang1-vmssLBNatPool.140
20.107.14.6
50022
yangwang1-vmss (instance 140)
SSH (TCP/22)
yangwang1-vmssLBNatPool.141
20.107.14.6
50023
yangwang1-vmss (instance 141)
SSH (TCP/22)
yangwang1-vmssLBNatPool.142
20.107.14.6
50024
yangwang1-vmss (instance 142)
SSH (TCP/22)
yangwang1-vmssLBNatPool.143
20.107.14.6
50025
yangwang1-vmss (instance 143)
SSH (TCP/22)
yangwang1-vmssLBNatPool.145
20.107.14.6
50027
yangwang1-vmss (instance 145)
SSH (TCP/22)
yangwang1-vmssLBNatPool.147
20.107.14.6
50029
yangwang1-vmss (instance 147)
SSH (TCP/22)
yangwang1-vmssLBNatPool.148
20.107.14.6
50030
yangwang1-vmss (instance 148)
SSH (TCP/22)
yangwang1-vmssLBNatPool.149
20.107.14.6
50031
yangwang1-vmss (instance 149)
SSH (TCP/22)
yangwang1-vmssLBNatPool.150
20.107.14.6
50032
yangwang1-vmss (instance 150)
SSH (TCP/22)
yangwang1-vmssLBNatPool.151
20.107.14.6
50033
yangwang1-vmss (instance 151)
SSH (TCP/22)
yangwang1-vmssLBNatPool.152
20.107.14.6
50034
yangwang1-vmss (instance 152)
SSH (TCP/22)
yangwang1-vmssLBNatPool.153
20.107.14.6
50035
yangwang1-vmss (instance 153)
SSH (TCP/22)
yangwang1-vmssLBNatPool.154
20.107.14.6
50036
yangwang1-vmss (instance 154)
SSH (TCP/22)
"""
# Use the findall method of the re module to find all strings that are prefixed with "yangwang1-"
# matches = re.findall(r'yangwang1-\w+', string)

matches1 = re.findall(r'yangwang1-000\w+', string1)
matches2 = re.findall(r'500\d+', string2)

# # Print the matches
# print(matches)

# computer_name_list = ['yangwang1-000039', 'yangwang1-00003A', 'yangwang1-00003B', 'yangwang1-00003C', 'yangwang1-00003E', 'yangwang1-00003F', 'yangwang1-00003G', 'yangwang1-00003H', 'yangwang1-00003I', 'yangwang1-00003J', 'yangwang1-00003K', 'yangwang1-00003L', 'yangwang1-00003M', 'yangwang1-00003N', 'yangwang1-00003O', 'yangwang1-00003P', 'yangwang1-00003Q', 'yangwang1-00003R', 'yangwang1-00003S', 'yangwang1-00003T', 'yangwang1-00003U', 'yangwang1-00003V', 'yangwang1-00003W', 'yangwang1-00003X', 'yangwang1-00003Y', 'yangwang1-00003Z', 'yangwang1-000040', 'yangwang1-000041', 'yangwang1-000042', 'yangwang1-000043', 'yangwang1-000044', 'yangwang1-000045', 'yangwang1-000046', 'yangwang1-000047', 'yangwang1-000048', 'yangwang1-000049', 'yangwang1-00004A', 'yangwang1-00004B']

for i in range(len(matches1)):
    print("{} ansible_port={}".format(matches1[i], matches2[i]))
# for computer_name in computer_name_list:
#     print(computer_name)